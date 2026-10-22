import CoreGraphics

/// 背景の厚みを、拡大前のアイコンに合わせて求める。拡大の余白はウィンドウ側が確保する。
enum DockBackdropFit {
    static let bottomContentInset: CGFloat = 10
    static let sideContentInset: CGFloat = 12
    static let runningIndicatorRow: CGFloat = 9
    static let tileHeight: CGFloat = 54
    static let sideTileWidth: CGFloat = 140

    static func bottomThickness(iconSize: Double, hasTile: Bool) -> CGFloat {
        let content = max(CGFloat(iconSize) + runningIndicatorRow, hasTile ? tileHeight : 0)
        return content + bottomContentInset * 2
    }

    static func sideThickness(iconSize: Double, hasTile: Bool) -> CGFloat {
        let content = max(CGFloat(iconSize), hasTile ? sideTileWidth : 0)
        return content + sideContentInset * 2
    }

    static let resizeHandleLength: CGFloat = 30
    static let verticalItemExtra: CGFloat = 9

    struct LengthContent: Equatable {
        var iconItems: Int
        var fixedExtent: CGFloat
        var minimizedSlots: Int
    }

    /// 並びの方向の背景の長さを、拡大前の項目の並びに合わせて求める。項目と背景の端の間隔は厚み側の余白と同じにする。
    static func length(_ content: LengthContent, iconSize: Double, axisPadding: CGFloat, vertical: Bool) -> CGFloat {
        let icon = CGFloat(iconSize)
        let slots = CGFloat(content.iconItems + 1)
        let iconExtent = icon + 2 * axisPadding + (vertical ? verticalItemExtra : 0)
        let inset = vertical ? sideContentInset : bottomContentInset
        return content.fixedExtent + slots * iconExtent + CGFloat(content.minimizedSlots) * (icon + 10)
            + resizeHandleLength + 2 * max(0, inset - axisPadding)
    }

    /// ホバー拡大で並びが伸びた分だけ背景を長くする。拡大していないときは `base` のままで、伸びた分はウィンドウの長さを超えない。
    static func magnifiedLength(base: CGFloat, iconSize: Double, scales: [Double], windowLength: CGFloat) -> CGFloat {
        let extra = scales.reduce(0) { $0 + max(0, CGFloat(iconSize * ($1 - 1))) }
        guard extra > 0 else { return base }
        return min(base + extra, max(base, windowLength))
    }
}
