import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class NativeDockTileState {
    enum Mode { case clock, focus }
    var mode: Mode = .clock
    var session = FocusSession()
    var now = Date()

    var seconds: Int { session.seconds(at: now) }
    var timerText: String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
    var isRunning: Bool { session.deadline != nil && seconds > 0 }
    var status: String { seconds == 0 ? "完了" : (isRunning ? "集中中" : "一時停止") }

    func toggle(at date: Date = .now) {
        now = date
        session.toggle(at: date)
        mode = .focus
    }

    func reset(at date: Date = .now) {
        now = date
        session = FocusSession()
    }
}

@MainActor
final class NativeDockTileView: NSView {
    let state: NativeDockTileState
    init(state: NativeDockTileState) {
        self.state = state
        super.init(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
        autoresizingMask = [.width, .height]
    }
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let scale = min(bounds.width, bounds.height) / 128
        guard scale > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = NSAffineTransform()
        transform.translateX(by: (bounds.width - 128 * scale) / 2, yBy: (bounds.height - 128 * scale) / 2)
        transform.scale(by: scale)
        transform.concat()
        let focus = state.mode == .focus
        let accent = focus ? NSColor.systemOrange : NSColor.systemBlue
        let card = NSBezierPath(roundedRect: NSRect(x: 5, y: 5, width: 118, height: 118), xRadius: 26, yRadius: 26)
        NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.17, alpha: 1).setFill()
        card.fill()
        accent.withAlphaComponent(0.8).setStroke()
        card.lineWidth = 2
        card.stroke()
        let text = focus ? state.timerText : state.now.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        drawText(focus ? "FOCUS" : "CLOCK", y: 91, size: 13, color: accent)
        drawText(text, y: 49, size: 32, color: .white)
        drawText(focus ? state.status : state.now.formatted(.dateTime.month(.twoDigits).day(.twoDigits)),
                 y: 29, size: 12, color: .lightGray)
        if focus {
            NSColor.white.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: NSRect(x: 23, y: 17, width: 82, height: 4), xRadius: 2, yRadius: 2).fill()
            accent.setFill()
            NSBezierPath(roundedRect: NSRect(x: 23, y: 17, width: 82 * min(1, Double(state.seconds) / 1500), height: 4), xRadius: 2, yRadius: 2).fill()
        }
    }

    private func drawText(_ text: String, y: CGFloat, size: CGFloat, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold), .foregroundColor: color
        ]
        let string = text as NSString
        let width = string.size(withAttributes: attributes).width
        string.draw(at: NSPoint(x: (128 - width) / 2, y: y), withAttributes: attributes)
    }
}

@MainActor
final class NativeDockTileController: NSObject {
    let state = NativeDockTileState()
    private let store: DockStore
    private let tile: NSDockTile
    private var timer: Timer?
    private var detailWindow: NSWindow?
    private var content: NativeDockTileView?

    init(store: DockStore, tile: NSDockTile? = nil) {
        self.store = store
        self.tile = tile ?? NSApplication.shared.dockTile
        super.init()
    }

    func start() {
        guard timer == nil else { return }
        let content = NativeDockTileView(state: state)
        self.content = content
        tile.contentView = content
        refresh()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        detailWindow?.close()
        detailWindow = nil
        tile.contentView = nil
        tile.badgeLabel = nil
        tile.display()
        content = nil
    }

    func refresh(at date: Date = .now) {
        state.now = date
        content?.setAccessibilityLabel(state.mode == .clock ? "時計" : "集中タイマー \(state.timerText) \(state.status)")
        tile.display()
    }

    func makeMenu() -> NSMenu {
        refresh()
        let menu = NSMenu()
        add("時計を表示", action: #selector(showClock), to: menu).state = state.mode == .clock ? .on : .off
        add("集中タイマーを表示", action: #selector(showFocus), to: menu).state = state.mode == .focus ? .on : .off
        menu.addItem(.separator())
        add(state.isRunning ? "タイマーを一時停止" : "25 分タイマーを開始・再開", action: #selector(toggleTimer), to: menu)
        add("タイマーをリセット", action: #selector(resetTimer), to: menu)
        add("詳細を開く…", action: #selector(showDetails), to: menu)
        menu.addItem(.separator())
        let profiles = NSMenuItem(title: "Custom Dock のプロファイル", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for profile in store.document.profiles {
            let item = add(profile.name, action: #selector(selectProfile(_:)), to: submenu)
            item.representedObject = profile.id.uuidString
            item.state = profile.id == store.document.activeProfileID ? .on : .off
            item.isEnabled = !store.storageIsReadOnly
        }
        submenu.autoenablesItems = false
        profiles.submenu = submenu
        menu.addItem(profiles)
        menu.addItem(NSMenuItem(title: "標準 Dock の配置は変更しません", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        add("Dock Studio を終了", action: #selector(quit), to: menu)
        return menu
    }

    @discardableResult
    private func add(_ title: String, action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc func showClock() { state.mode = .clock; refresh() }
    @objc func showFocus() { state.mode = .focus; refresh() }
    @objc func toggleTimer() { state.toggle(); refresh() }
    @objc func resetTimer() { state.reset(); refresh() }
    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let id = UUID(uuidString: value) else { return }
        store.activateProfile(id)
        if let error = store.errorMessage {
            let alert = NSAlert()
            alert.messageText = "プロファイルを切り替えられませんでした"
            alert.informativeText = error
            alert.runModal()
        }
    }
    @objc private func quit() { NSApplication.shared.terminate(nil) }

    @objc func showDetails() {
        if detailWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 290),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Dock Studio — 標準 Dock"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: NativeDockTileDetail(controller: self))
            window.center()
            detailWindow = window
        }
        detailWindow?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

struct NativeDockTileDetail: View {
    let controller: NativeDockTileController
    var body: some View {
        VStack(spacing: 16) {
            Text(controller.state.mode == .clock ? "時計" : "集中タイマー").font(.headline)
            Text(controller.state.mode == .clock
                 ? controller.state.now.formatted(date: .omitted, time: .shortened)
                 : controller.state.timerText)
                .font(.system(size: 48, weight: .medium, design: .rounded)).monospacedDigit()
            HStack {
                Button("時計") { controller.showClock() }
                Button("タイマー") { controller.showFocus() }
            }
            HStack {
                Button(controller.state.isRunning ? "一時停止" : "開始・再開") { controller.toggleTimer() }
                Button("リセット") { controller.resetTimer() }
            }
            Text("標準 Dock のアイコンを右クリックして操作できます。")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(24).frame(width: 320, height: 290)
    }
}
