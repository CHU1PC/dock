import CoreGraphics
import Foundation

/// 下配置の Dock バーの各要素の位置を求める純粋関数。座標はパネル左下を原点とし、y は上向きに増える。
enum DockBarLayout {
    static let bottomGap = DockInteractionGeometry.bottomGap
    static let panelPadding = DockInteractionGeometry.panelPadding
    static let contentHorizontalInset: CGFloat = 12
    static let contentBottomInset: CGFloat = 10
    static let dividerWidth: CGFloat = 11
    static let spacerWidth: CGFloat = 11
    static let clockWidth: CGFloat = 135
    static let focusTimerWidth: CGFloat = 120
    static let minimizedItemPadding: CGFloat = 10
    static let springResponse = 0.24
    static let springDampingFraction = 0.82

    struct Frames: Equatable {
        var backdrop: CGRect
        /// 項目の並び順で、アイコンを持たない種別は nil。
        var tiles: [CGRect?]
        /// ホバー判定に使う、アイコンの左右の余白を含む矩形。
        var slots: [CGRect?]
    }

    static func isIconKind(_ kind: DockItemKind) -> Bool {
        ![.spacer, .clock, .focusTimer].contains(kind)
    }

    static func axisPadding(for snapshot: DockBarSnapshot) -> CGFloat {
        guard snapshot.appearance.background == .appleDock, snapshot.maximumIconSize > 0 else { return 5 }
        return CGFloat(5 * min(1, snapshot.iconSize / snapshot.maximumIconSize))
    }

    static func maximumScale(for snapshot: DockBarSnapshot) -> Double {
        snapshot.magnificationEnabled ? snapshot.appearance.magnificationScale : 1
    }

    static func metricsInput(snapshot: DockBarSnapshot, minimizedSlots: Int) -> DockMetricsInput {
        var dividers = Set(snapshot.items.indices.filter { snapshot.items[$0].dividerBefore })
        if snapshot.trash.dividerBefore { dividers.insert(snapshot.items.count) }
        return DockMetricsInput(
            kinds: snapshot.items.map(\.kind), dividerBefore: dividers, position: snapshot.position,
            effectiveIconSize: snapshot.maximumIconSize, background: snapshot.appearance.background,
            magnification: snapshot.magnificationEnabled, magnificationScale: snapshot.appearance.magnificationScale,
            minimizedSlots: minimizedSlots)
    }

    @MainActor
    static func frames(snapshot: DockBarSnapshot, minimizedSlots: Int, panelSize: CGSize,
                       hoveredIndex: Int?) -> Frames {
        let iconSize = snapshot.iconSize
        let padding = axisPadding(for: snapshot)
        let maximum = maximumScale(for: snapshot)
        let input = metricsInput(snapshot: snapshot, minimizedSlots: minimizedSlots)

        var cursor = contentHorizontalInset
        var tiles: [CGRect?] = []
        var slots: [CGRect?] = []
        let tileY = bottomGap + contentBottomInset + DockBackdropFit.runningIndicatorRow
        for (index, item) in snapshot.items.enumerated() {
            if item.dividerBefore { cursor += dividerWidth }
            switch item.kind {
            case .spacer: cursor += spacerWidth; tiles.append(nil); slots.append(nil)
            case .clock: cursor += clockWidth; tiles.append(nil); slots.append(nil)
            case .focusTimer: cursor += focusTimerWidth; tiles.append(nil); slots.append(nil)
            default:
                let side = CGFloat(iconSize * DockAppearance.scale(index: index, hovered: hoveredIndex, maximum: maximum))
                tiles.append(CGRect(x: cursor + padding, y: tileY, width: side, height: side))
                slots.append(CGRect(x: cursor, y: bottomGap, width: side + 2 * padding, height: tileY - bottomGap + side))
                cursor += side + 2 * padding
            }
        }
        if snapshot.trash.dividerBefore { cursor += dividerWidth }
        cursor += CGFloat(minimizedSlots) * (CGFloat(iconSize) + minimizedItemPadding)
        cursor += DockBackdropFit.resizeHandleLength
        let trashScale = DockAppearance.scale(index: snapshot.items.count, hovered: hoveredIndex, maximum: maximum)
        cursor += CGFloat(iconSize * trashScale) + 2 * padding + contentHorizontalInset

        let offset = (panelSize.width - cursor) / 2
        tiles = tiles.map { $0?.offsetBy(dx: offset, dy: 0) }
        slots = slots.map { $0?.offsetBy(dx: offset, dy: 0) }

        let enabled = snapshot.magnificationEnabled
        let windowLength = DockMetrics.length(for: input, magnificationEnabled: enabled, iconSize: iconSize)
        let length = min(DockMetrics.backdropLength(for: input, iconSize: iconSize, axisPadding: padding,
                                                    hoveredIndex: hoveredIndex, magnificationScale: maximum,
                                                    windowLength: windowLength),
                         max(0, panelSize.width - panelPadding * 2))
        let thickness = DockMetrics.backdropThickness(for: input)
        let backdrop = CGRect(x: (panelSize.width - length) / 2, y: bottomGap, width: length, height: thickness)
        return Frames(backdrop: backdrop, tiles: tiles, slots: slots)
    }

    /// カーソル下のアイコンの位置を返す。どのアイコンの上でもなければ、いまのホバーを保つ。
    static func hoveredIndex(atX x: CGFloat, slots: [CGRect?], current: Int?) -> Int? {
        for (index, slot) in slots.enumerated() {
            if let slot, x >= slot.minX, x < slot.maxX { return index }
        }
        return current
    }

    /// SwiftUI の `.spring(response:dampingFraction:)` と同じ動きになる質量 1 のバネの係数。
    static func springParameters(response: Double, dampingFraction: Double) -> (stiffness: Double, damping: Double) {
        let omega = 2 * Double.pi / response
        return (omega * omega, 2 * dampingFraction * omega)
    }
}

/// レイヤーを作り直す必要があるかを決める、項目の並びと見た目の鍵。
struct DockBarStructure: Equatable {
    struct Entry: Equatable {
        let id: UUID
        let iconKey: String
        let isUnavailable: Bool
    }

    let entries: [Entry]
    let iconStyle: DockAppearance.IconStyle
    let iconSize: Double
    let maximumScale: Double

    init(snapshot: DockBarSnapshot) {
        entries = snapshot.items.map { Entry(id: $0.id, iconKey: $0.iconKey, isUnavailable: $0.availability.isUnavailable) }
        iconStyle = snapshot.appearance.iconStyle
        iconSize = snapshot.iconSize
        maximumScale = DockBarLayout.maximumScale(for: snapshot)
    }
}

/// レイヤー版の背景の見た目。透明と単色の塗りだけを扱い、ぼかしやガラスは平らな塗りで代用する。
struct DockBarBackdropStyle: Equatable {
    var fillRGB: UInt32
    var fillAlpha: Double
    var borderAlpha: Double
    var shadowOpacity: Double

    init(appearance: DockAppearance) {
        guard appearance.background != .transparent else {
            fillRGB = 0; fillAlpha = 0; borderAlpha = 0; shadowOpacity = 0
            return
        }
        fillRGB = appearance.color
        fillAlpha = appearance.opacity
        borderAlpha = 0.22 * appearance.opacity
        shadowOpacity = appearance.background == .appleDock ? 0 : 0.18
    }
}
