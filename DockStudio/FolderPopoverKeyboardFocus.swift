import AppKit
import SwiftUI

enum FolderPopoverKeyboardFocus {
    static func initialGridItemID(mode: FolderDisplayMode, items: [DockItem]) -> UUID? {
        guard mode == .grid else { return nil }
        return items.first?.id
    }
}

struct PopoverWindowKeyRequester: NSViewRepresentable {
    let onWindowKey: () -> Void

    func makeNSView(context: Context) -> NSView {
        PopoverKeyRequesterView(onWindowKey: onWindowKey)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? PopoverKeyRequesterView)?.onWindowKey = onWindowKey
    }
}

private final class PopoverKeyRequesterView: NSView {
    var onWindowKey: () -> Void
    private var requestedWindowID: ObjectIdentifier?

    init(onWindowKey: @escaping () -> Void) {
        self.onWindowKey = onWindowKey
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, requestedWindowID != ObjectIdentifier(window) else { return }
        requestedWindowID = ObjectIdentifier(window)
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            if !window.isKeyWindow { window.makeKey() }
            self.onWindowKey()
        }
    }
}
