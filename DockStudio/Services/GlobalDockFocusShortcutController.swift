import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalDockFocusShortcutController {
    private let store: DockStore
    private var handler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var registeredShortcut: DockFocusShortcut?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x444F434B), id: 47)

    init(store: DockStore) {
        self.store = store
    }

    func update(shortcut: DockFocusShortcut) {
        guard registeredShortcut != shortcut || hotKey == nil else { return }
        unregisterHotKey()
        guard installHandler() else { return }

        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else {
            store.dockFocusShortcutMessage = "選んだキーを登録できませんでした。別のキーを選んでください。"
            return
        }
        hotKey = reference
        registeredShortcut = shortcut
        store.dockFocusShortcutMessage = nil
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }

    private func installHandler() -> Bool {
        guard handler == nil else { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        var reference: EventHandlerRef?
        let status = InstallEventHandler(GetApplicationEventTarget(), dockHotKeyPressed,
                                         1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &reference)
        guard status == noErr, let reference else {
            store.dockFocusShortcutMessage = "グローバルショートカットを初期化できませんでした。"
            return false
        }
        handler = reference
        return true
    }

    private func unregisterHotKey() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        registeredShortcut = nil
    }

    fileprivate func handleHotKey(_ event: EventRef) {
        var pressedID = EventHotKeyID()
        let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                       EventParamType(typeEventHotKeyID), nil,
                                       MemoryLayout<EventHotKeyID>.size, nil, &pressedID)
        guard status == noErr, pressedID.signature == hotKeyID.signature,
              pressedID.id == hotKeyID.id else { return }
        store.focusDock()
    }
}

private let dockHotKeyPressed: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return noErr }
    let controller = Unmanaged<GlobalDockFocusShortcutController>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { controller.handleHotKey(event) }
    return noErr
}
