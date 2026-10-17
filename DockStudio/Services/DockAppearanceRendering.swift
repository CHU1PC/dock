import AppKit
import SwiftUI
import ImageIO
import OSLog

@MainActor
enum DockIconRenderer {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 16 * 1024 * 1024
        cache.countLimit = 128
        return cache
    }()

    static func image(url: URL, style: DockAppearance.IconStyle) -> NSImage {
        let key = "\(url.path)|\(style.rawValue)" as NSString
        if let image = cache.object(forKey: key) { return image }
        let original = NSWorkspace.shared.icon(forFile: url.path)
        if style == .original {
            cache.setObject(original, forKey: key, cost: 512 * 512 * 4)
            return original
        }
        let pixels = Int(ceil(76 * 2 * max(2, NSScreen.screens.map(\.backingScaleFactor).max() ?? 2)))
        let image = render(original, style: style, pixels: pixels)
        cache.setObject(image, forKey: key, cost: pixels * pixels * 4)
        return image
    }

    static func invalidate() { cache.removeAllObjects() }

    static func render(_ original: NSImage, style: DockAppearance.IconStyle, pixels: Int) -> NSImage {
        guard pixels > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                      bytesPerRow: pixels * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data else {
            Logger(subsystem: "app.dockstudio.preview", category: "icons").error("Unable to create icon conversion bitmap")
            return original
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        original.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let bytes = data.bindMemory(to: UInt8.self, capacity: pixels * pixels * 4)
        if style != .original {
            for i in stride(from: 0, to: pixels * pixels * 4, by: 4) {
                let converted = transformed(red: bytes[i], green: bytes[i + 1], blue: bytes[i + 2], alpha: bytes[i + 3], style: style)
                bytes[i] = converted.0; bytes[i + 1] = converted.1
                bytes[i + 2] = converted.2; bytes[i + 3] = converted.3
            }
        }
        guard let result = context.makeImage() else {
            Logger(subsystem: "app.dockstudio.preview", category: "icons").error("Unable to finalize converted icon")
            return original
        }
        return NSImage(cgImage: result, size: NSSize(width: pixels, height: pixels))
    }

    private static var backgroundCache: (path: String, checked: Date, version: TimeInterval, image: NSImage?)?

    static func background(path: String) -> NSImage? {
        let now = Date()
        if let cached = backgroundCache, cached.path == path, now.timeIntervalSince(cached.checked) < 1 {
            return cached.image
        }
        let url = URL(fileURLWithPath: path)
        let version = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0
        if let cached = backgroundCache, cached.path == path, cached.version == version {
            backgroundCache = (path, now, version, cached.image)
            return cached.image
        }
        var result: NSImage?
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048
           ] as CFDictionary) {
            result = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        }
        backgroundCache = (path, now, version, result)
        return result
    }

    static func transformed(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8,
                            style: DockAppearance.IconStyle) -> (UInt8, UInt8, UInt8, UInt8) {
        guard style != .original else { return (red, green, blue, alpha) }
        let luminance = (Double(red) * 0.2126 + Double(green) * 0.7152 + Double(blue) * 0.0722)
        if style == .monochrome {
            let value = UInt8(min(Double(alpha), luminance))
            return (value, value, value, alpha)
        }
        let newAlpha = Double(alpha) * 0.72
        let shade = alpha == 0 ? 0 : 0.45 + 0.55 * min(1, luminance / Double(alpha))
        let value = UInt8(newAlpha * shade)
        return (value, value, value, UInt8(newAlpha))
    }
}

struct DockSystemMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = CGFloat(DockAppearance.cornerRadius)
            return glass
        }
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        return effect
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct DockBackdrop: View {
    let appearance: DockAppearance
    private var tint: Color {
        Color(red: Double((appearance.color >> 16) & 255) / 255,
              green: Double((appearance.color >> 8) & 255) / 255,
              blue: Double(appearance.color & 255) / 255)
    }
    var body: some View {
        ZStack {
            if appearance.background != .transparent {
                if appearance.blur { DockSystemMaterial().opacity(appearance.opacity) }
                switch appearance.background {
                case .system: (appearance.blur ? Color.white.opacity(0.06) : tint).opacity(appearance.opacity)
                case .color: tint.opacity(appearance.opacity)
                case .image:
                    if let path = appearance.image, let image = DockIconRenderer.background(path: path) {
                        GeometryReader { geometry in
                            Image(nsImage: image).resizable().scaledToFill()
                                .frame(width: geometry.size.width + 48, height: geometry.size.height + 48)
                                .blur(radius: appearance.blur ? 12 : 0)
                                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                                .opacity(appearance.opacity)
                        }
                    } else { tint.opacity(appearance.opacity) }
                case .transparent: EmptyView()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(DockAppearance.cornerRadius), style: .continuous))
        .overlay {
            if appearance.background != .transparent {
                RoundedRectangle(cornerRadius: CGFloat(DockAppearance.cornerRadius), style: .continuous)
                    .strokeBorder(.white.opacity(0.22 * appearance.opacity), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}
