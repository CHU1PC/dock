import AppKit
import Carbon

@MainActor
final class DockAppDelegate: NSObject, NSApplicationDelegate {
    weak var store: DockStore?
    weak var loginLaunchState: LoginLaunchState?
    private var dockController: CustomDockWindowController?
    private var nativeTile: NativeDockTileController?
    var tileOnly = false
    var tileNotice = ""

    func observeLoginLaunchEvents() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenApplication(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenApplication)
        )
    }

    @objc private func handleOpenApplication(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        loginLaunchState?.recordOpenApplicationEvent(event)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let store else { return }
        if tileOnly {
            let controller = NativeDockTileController(store: store, notice: tileNotice)
            nativeTile = controller
            controller.start()
        } else {
            dockController = CustomDockWindowController(store: store)
        }
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        nativeTile?.makeMenu()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard tileOnly else { return true }
        nativeTile?.showDetails()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        nativeTile?.stop()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        guard !store.isChoosingDockBackground else {
            let alert = NSAlert()
            alert.messageText = "背景画像を読み込み中です"
            alert.informativeText = "画像の読み込みが終わってから、もう一度終了してください。"
            alert.runModal()
            return .terminateCancel
        }
        guard store.finishIconSizeEditing(), store.finishRevealAnimationDurationEditing(),
              store.finishAppearanceEditing() else { return cancelAfterSaveFailure(store) }
        guard store.hasPendingDrafts else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "未保存の編集内容があります"
        alert.informativeText = store.draftRecoveryFailed
            ? "下書きの復元用データを保存できていません。変更を保存してから終了してください。"
            : "変更を保存して終了するか、下書きを残して次回再開できます。"
        alert.addButton(withTitle: "すべて保存して終了")
        alert.addButton(withTitle: "キャンセル")
        if !store.draftRecoveryFailed { alert.addButton(withTitle: "下書きを残して終了") }
        switch alert.runModal() {
        case .alertFirstButtonReturn: return store.saveAllDrafts() ? .terminateNow : cancelAfterSaveFailure(store)
        case .alertThirdButtonReturn: return .terminateNow
        default: return .terminateCancel
        }
    }

    private func cancelAfterSaveFailure(_ store: DockStore) -> NSApplication.TerminateReply {
        let alert = NSAlert()
        alert.messageText = "保存できないため、終了を取り消しました"
        alert.informativeText = store.errorMessage ?? "変更を保存してから終了してください。"
        alert.runModal()
        return .terminateCancel
    }
}
