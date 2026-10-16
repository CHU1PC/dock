import AppKit
import SwiftUI

@main
struct CaptureNativeDockTile {
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let window = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: 320, height: 290),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let controller = NativeDockTileController(store: .preview(), tile: window.dockTile)
        let state = controller.state
        func capture(_ view: NSView, name: String) throws {
            let size = view.frame.size
            window.setContentSize(size)
            window.contentView = view
            view.frame = NSRect(origin: .zero, size: size)
            window.orderFront(nil)
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            view.layoutSubtreeIfNeeded()
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
        }
        let tile = NativeDockTileView(state: state)
        try capture(tile, name: "clock")
        let start = Date()
        state.toggle(at: start)
        state.now = start.addingTimeInterval(61)
        try capture(tile, name: "timer")
        let detail = NSHostingView(rootView: NativeDockTileDetail(controller: controller)
            .preferredColorScheme(.dark).background(Color(nsColor: .windowBackgroundColor)))
        detail.frame = NSRect(x: 0, y: 0, width: 320, height: 290)
        try capture(detail, name: "detail")
        state.reset(at: start)
        for frame in 0..<12 {
            if frame == 0 { state.mode = .clock }
            if frame == 2 { state.mode = .focus }
            if frame == 4 { state.toggle(at: start) }
            if frame >= 4 && frame < 8 { state.now = start.addingTimeInterval(Double(frame - 4)) }
            if frame == 8 { state.toggle(at: start.addingTimeInterval(4)) }
            if frame == 10 { state.reset(at: start.addingTimeInterval(6)) }
            try capture(tile, name: String(format: "frame-%02d", frame))
        }
        let menu = controller.makeMenu()
        let menuTitles = menu.items.map(\.title).joined(separator: "\n")
        try menuTitles.write(to: output.appendingPathComponent("menu.txt"), atomically: true, encoding: .utf8)
        window.orderOut(nil)
        print("Captured clock, timer, detail, 12 frames and menu titles at \(output.path)")
    }
}
