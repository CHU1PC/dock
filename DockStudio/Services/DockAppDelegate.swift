import AppKit

@MainActor
final class DockAppDelegate: NSObject, NSApplicationDelegate {
    weak var store: DockStore?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        guard store.finishIconSizeEditing() else { return cancelAfterSaveFailure(store) }
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
