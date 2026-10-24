import AppKit
import SwiftUI

/// タイルのアクセシビリティ要素。フレームは表示中のレイヤーに追従させる。
final class DockBarTileElement: NSAccessibilityElement {
    weak var layer: CALayer?
    weak var host: NSView?
    var onPress: (() -> Void)?

    override func accessibilityFrame() -> NSRect {
        guard let layer, let host, let window = host.window else { return .zero }
        let frame = (layer.presentation() ?? layer).frame
        return window.convertToScreen(host.convert(frame, to: nil))
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return onPress != nil
    }
}

/// Core Animation で描く下配置の Dock バー。ホバーはこのビューの中だけで完結し、store や SwiftUI を通らない。
@MainActor
final class DockBarView: NSView {
    private final class Tile {
        let id: UUID
        let index: Int
        let layer = CALayer()
        let element = DockBarTileElement()
        init(id: UUID, index: Int) { self.id = id; self.index = index }
    }

    var onClick: ((UUID, NSEvent.ModifierFlags) -> Void)?
    var iconImage: ((UUID, Double, ColorScheme) -> NSImage?)?
    private(set) var hoveredIndex: Int?
    var isCollapsed = false {
        didSet {
            guard isCollapsed != oldValue else { return }
            isHidden = isCollapsed
            if isCollapsed { setHovered(nil, animated: false) }
        }
    }

    private let backdropLayer = CALayer()
    private var tiles: [Tile] = []
    private var snapshot: DockBarSnapshot?
    private var structure: DockBarStructure?
    private var minimizedSlots = 0
    private var frames: DockBarLayout.Frames?
    private var trackingArea: NSTrackingArea?
    private var pressedID: UUID?
    private var iconCache: [String: CGImage] = [:]

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        backdropLayer.anchorPoint = CGPoint(x: 0.5, y: 0)
        backdropLayer.cornerRadius = CGFloat(DockAppearance.cornerRadius)
        backdropLayer.cornerCurve = .continuous
        layer?.addSublayer(backdropLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var tileCount: Int { tiles.count }

    func apply(snapshot: DockBarSnapshot, minimizedSlots: Int) {
        let oldIDs = self.snapshot?.items.map(\.id)
        self.snapshot = snapshot
        self.minimizedSlots = minimizedSlots
        let newStructure = DockBarStructure(snapshot: snapshot)
        if newStructure != structure {
            structure = newStructure
            if oldIDs != snapshot.items.map(\.id) { hoveredIndex = nil }
            rebuildTiles()
        } else {
            for tile in tiles { tile.element.setAccessibilityLabel(snapshot.items[tile.index].title) }
        }
        configureBackdrop(snapshot.appearance)
        applyLayout(animated: false)
    }

    override func layout() {
        super.layout()
        if snapshot != nil { applyLayout(animated: false) }
    }

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    /// ignoresMouseEvents の切り替え後に、追跡領域を登録し直す。
    func refreshTrackingArea() { updateTrackingAreas() }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        iconCache.removeAll()
        if snapshot != nil { rebuildTiles(); applyLayout(animated: false) }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        invalidateIcons()
    }

    /// アイコンのキャッシュを捨てて、いまの項目のレイヤーを作り直す。
    func invalidateIcons() {
        iconCache.removeAll()
        if snapshot != nil { rebuildTiles(); applyLayout(animated: false) }
    }

    // MARK: - Pointer

    override func mouseMoved(with event: NSEvent) {
        guard let frames else { return }
        let point = convert(event.locationInWindow, from: nil)
        let index = DockBarLayout.hoveredIndex(atX: point.x, slots: frames.slots, current: hoveredIndex)
        setHovered(index, animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovered(nil, animated: true)
    }

    /// 追跡領域のイベントに頼らず、スクリーン座標のポインタからホバーを決める。nil はバーの外。
    func setHoveredFromScreenPoint(_ screenPoint: NSPoint?) {
        guard let frames else { return }
        var x: CGFloat?
        if let screenPoint, let window {
            let inWindow = window.convertFromScreen(NSRect(origin: screenPoint, size: .zero)).origin
            x = convert(inWindow, from: nil).x
        }
        setHovered(DockBarLayout.resolvedHover(x: x, slots: frames.slots, current: hoveredIndex), animated: true)
    }

    override func mouseDown(with event: NSEvent) {
        pressedID = tile(at: convert(event.locationInWindow, from: nil))?.id
    }

    override func mouseUp(with event: NSEvent) {
        defer { pressedID = nil }
        guard let pressedID, tile(at: convert(event.locationInWindow, from: nil))?.id == pressedID else { return }
        onClick?(pressedID, event.modifierFlags)
    }

    private func tile(at point: CGPoint) -> Tile? {
        guard let frames else { return nil }
        return tiles.first { frames.slots[$0.index]?.contains(point) == true }
    }

    private func setHovered(_ index: Int?, animated: Bool) {
        guard index != hoveredIndex || DockBarLayout.isLayoutStale(frames, hoveredIndex: index) else { return }
        hoveredIndex = index
        applyLayout(animated: animated && snapshot?.reduceMotion == false)
    }

    // MARK: - Layers

    private var backingScale: CGFloat { window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2 }

    private var colorScheme: ColorScheme {
        effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }

    private func rebuildTiles() {
        guard let snapshot else { return }
        for tile in tiles { tile.layer.removeFromSuperlayer() }
        tiles = []
        let scale = backingScale
        for (index, item) in snapshot.items.enumerated() where DockBarLayout.isIconKind(item.kind) {
            let tile = Tile(id: item.id, index: index)
            tile.layer.anchorPoint = CGPoint(x: 0.5, y: 0)
            tile.layer.contentsGravity = .resize
            tile.layer.contentsScale = scale
            tile.layer.minificationFilter = .trilinear
            tile.layer.opacity = item.availability.isUnavailable ? 0.75 : 1
            tile.layer.contents = icon(for: item, snapshot: snapshot)
            layer?.addSublayer(tile.layer)
            let element = tile.element
            element.layer = tile.layer
            element.host = self
            element.setAccessibilityRole(.button)
            element.setAccessibilityLabel(item.title)
            element.setAccessibilityIdentifier("dockbar-tile-\(index)")
            element.setAccessibilityParent(self)
            let id = item.id
            element.onPress = { [weak self] in self?.onClick?(id, []) }
            tiles.append(tile)
        }
    }

    private func configureBackdrop(_ appearance: DockAppearance) {
        let style = DockBarBackdropStyle(appearance: appearance)
        let fill = NSColor(srgbRed: CGFloat((style.fillRGB >> 16) & 255) / 255, green: CGFloat((style.fillRGB >> 8) & 255) / 255,
                           blue: CGFloat(style.fillRGB & 255) / 255, alpha: style.fillAlpha)
        backdropLayer.backgroundColor = fill.cgColor
        backdropLayer.borderWidth = style.borderAlpha > 0 ? 1 : 0
        backdropLayer.borderColor = NSColor(white: 1, alpha: style.borderAlpha).cgColor
        backdropLayer.shadowColor = NSColor.black.cgColor
        backdropLayer.shadowOpacity = Float(style.shadowOpacity)
        backdropLayer.shadowRadius = 4
        backdropLayer.shadowOffset = CGSize(width: 0, height: 2)
    }

    private func applyLayout(animated: Bool) {
        guard let snapshot else { return }
        let target = DockBarLayout.frames(snapshot: snapshot, minimizedSlots: minimizedSlots,
                                          panelSize: bounds.size, hoveredIndex: hoveredIndex)
        frames = target
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        place(backdropLayer, in: target.backdrop, animated: animated, shadow: true)
        for tile in tiles {
            if let rect = target.tiles[tile.index] { place(tile.layer, in: rect, animated: animated, shadow: false) }
        }
        CATransaction.commit()
    }

    private func place(_ layer: CALayer, in rect: CGRect, animated: Bool, shadow: Bool) {
        let size = rect.size
        let position = CGPoint(x: rect.midX, y: rect.minY)
        let current = layer.presentation() ?? layer
        let fromSize = current.bounds.size
        let fromPosition = current.position
        let fromPath = current.shadowPath
        layer.bounds = CGRect(origin: .zero, size: size)
        layer.position = position
        let path = shadow ? Self.shadowPath(size) : nil
        if shadow { layer.shadowPath = path }
        guard animated else {
            layer.removeAllAnimations()
            return
        }
        guard fromSize != size || fromPosition != position else { return }
        layer.add(Self.spring("bounds.size", from: NSValue(size: fromSize), to: NSValue(size: size)), forKey: "bounds.size")
        layer.add(Self.spring("position", from: NSValue(point: fromPosition), to: NSValue(point: position)), forKey: "position")
        if let path, let fromPath {
            layer.add(Self.spring("shadowPath", from: fromPath, to: path), forKey: "shadowPath")
        }
    }

    private static func shadowPath(_ size: CGSize) -> CGPath {
        let radius = min(CGFloat(DockAppearance.cornerRadius), size.width / 2, size.height / 2)
        return CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    private static func spring(_ keyPath: String, from: Any, to: Any) -> CASpringAnimation {
        let parameters = DockBarLayout.springParameters(response: DockBarLayout.springResponse,
                                                        dampingFraction: DockBarLayout.springDampingFraction)
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.mass = 1
        animation.stiffness = parameters.stiffness
        animation.damping = parameters.damping
        animation.fromValue = from
        animation.toValue = to
        animation.duration = animation.settlingDuration
        return animation
    }

    // MARK: - Icons

    private func icon(for item: DockBarSnapshot.Item, snapshot: DockBarSnapshot) -> CGImage? {
        let pointSize = snapshot.iconSize * DockBarLayout.maximumScale(for: snapshot)
        let pixels = DockIconConversionPolicy.pixelSize(pointSize: pointSize, backingScaleFactor: Double(backingScale))
        let scheme = colorScheme
        let key = "\(item.iconKey)|\(snapshot.appearance.iconStyle.rawValue)|\(scheme == .dark)|\(pixels)|\(item.availability.isUnavailable)"
        if let cached = iconCache[key] { return cached }
        let source: NSImage?
        if item.availability.isUnavailable {
            source = Self.symbolImage(item.availability == .volumeNotMounted ? "externaldrive.badge.xmark" : "questionmark.square.dashed", pixels: pixels)
        } else {
            source = iconImage?(item.id, pointSize, scheme) ?? Self.symbolImage(item.kind.symbol, pixels: pixels)
        }
        guard let source, let image = Self.cgImage(source, pixels: pixels) else { return nil }
        iconCache[key] = image
        return image
    }

    private static func cgImage(_ image: NSImage, pixels: Int) -> CGImage? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    /// アプリのアイコンを持たない項目と、使えない項目に描く、角丸の下地つきのシンボル。
    private static func symbolImage(_ name: String, pixels: Int) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: CGFloat(pixels) * 0.5, weight: .medium)) else { return nil }
        let side = CGFloat(pixels)
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor(white: 1, alpha: 0.2).setFill()
            NSBezierPath(roundedRect: rect, xRadius: side * 0.23, yRadius: side * 0.23).fill()
            let tinted = NSImage(size: symbol.size, flipped: false) { symbolRect in
                symbol.draw(in: symbolRect)
                NSColor.white.set()
                symbolRect.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: NSRect(x: (side - symbol.size.width) / 2, y: (side - symbol.size.height) / 2,
                                   width: symbol.size.width, height: symbol.size.height))
            return true
        }
    }

    // MARK: - Accessibility

    override func isAccessibilityElement() -> Bool { false }
    override func accessibilityChildren() -> [Any]? { tiles.map(\.element) }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
}
