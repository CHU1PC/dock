import AppKit
import SwiftUI

enum FolderPopoverKeyboardFocus {
    enum KeyRoute: Equatable {
        case dismiss
        case left
        case right
        case up
        case down
    }

    static func initialGridItemID(mode: FolderDisplayMode, items: [DockItem]) -> UUID? {
        guard mode == .grid else { return nil }
        return items.first?.id
    }

    static func keyRoute(keyCode: UInt16, isPopoverOpen: Bool) -> KeyRoute? {
        guard isPopoverOpen else { return nil }
        return switch keyCode {
        case 53: .dismiss
        case 123: .left
        case 124: .right
        case 125: .down
        case 126: .up
        default: nil
        }
    }

    @MainActor
    enum ActiveKeyRouter {
        private static var activeID: UUID?
        private static var handler: ((UInt16) -> Void)?

        static func register(id: UUID, handler: @escaping (UInt16) -> Void) {
            activeID = id
            self.handler = handler
        }

        static func unregister(id: UUID) {
            guard activeID == id else { return }
            activeID = nil
            handler = nil
        }

        @discardableResult
        static func route(keyCode: UInt16) -> Bool {
            guard let handler,
                  FolderPopoverKeyboardFocus.keyRoute(keyCode: keyCode, isPopoverOpen: true) != nil else {
                return false
            }
            handler(keyCode)
            return true
        }
    }
}

struct PopoverWindowKeyRequester: NSViewRepresentable {
    let onWindowKey: () -> Void
    let onKeyDown: (UInt16) -> Void

    func makeNSView(context: Context) -> NSView {
        PopoverKeyRequesterView(onWindowKey: onWindowKey, onKeyDown: onKeyDown)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? PopoverKeyRequesterView else { return }
        view.onWindowKey = onWindowKey
        view.onKeyDown = onKeyDown
        view.updateKeyRouter()
    }
}

private final class PopoverKeyRequesterView: NSView {
    var onWindowKey: () -> Void
    var onKeyDown: (UInt16) -> Void
    private let routingID = UUID()
    private var requestedWindowID: ObjectIdentifier?
    private var keyDownMonitor: Any?

    init(onWindowKey: @escaping () -> Void, onKeyDown: @escaping (UInt16) -> Void) {
        self.onWindowKey = onWindowKey
        self.onKeyDown = onKeyDown
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else {
            removeKeyDownMonitor()
            FolderPopoverKeyboardFocus.ActiveKeyRouter.unregister(id: routingID)
            requestedWindowID = nil
            return
        }
        updateKeyRouter()
        if keyDownMonitor == nil {
            keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      FolderPopoverKeyboardFocus.keyRoute(keyCode: event.keyCode, isPopoverOpen: true) != nil else {
                    return event
                }
                self.onKeyDown(event.keyCode)
                return nil
            }
        }
        guard requestedWindowID != ObjectIdentifier(window) else { return }
        requestedWindowID = ObjectIdentifier(window)
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            if !window.isKeyWindow { window.makeKey() }
            self.onWindowKey()
        }
    }

    deinit {
        removeKeyDownMonitor()
        MainActor.assumeIsolated {
            FolderPopoverKeyboardFocus.ActiveKeyRouter.unregister(id: routingID)
        }
    }

    private func removeKeyDownMonitor() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }
    }

    func updateKeyRouter() {
        guard window != nil else { return }
        FolderPopoverKeyboardFocus.ActiveKeyRouter.register(id: routingID, handler: onKeyDown)
    }
}
