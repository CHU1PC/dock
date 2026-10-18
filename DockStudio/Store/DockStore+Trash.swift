import AppKit

extension DockStore {
    static let trashItem = DockItem(id: UUID(uuidString: "7A5C0000-0000-4000-8000-000000000001")!,
                                    name: "ゴミ箱", kind: .folder)

    var trashURL: URL {
        (try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
    }

    var trashStateGuidance: String {
        "Finder の項目数を読み取れないため、ゴミ箱の状態を確認できません。システム設定の「プライバシーとセキュリティ」＞「オートメーション」で、Dock Studio から Finder への操作を許可してください。"
    }

    func explainTrashState() {
        errorMessage = trashStateGuidance
    }

    static func hoverableItems(_ items: [DockItem]) -> [DockItem] { items + [trashItem] }

    func startTrashMonitoring() {
        guard !isPreview else { return }
        trashMonitor = Task { [weak self] in
            while !Task.isCancelled {
                guard await self?.pollTrash() != nil else { return }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func pollTrash() async {
        if isDockEffectivelyVisible { await refreshTrash() }
    }

    func refreshTrash() async {
        let inspector = trashInspector
        let state = await Task.detached(priority: .utility) { inspector.state() }.value
        if trashState != state { trashState = state }
    }

    func openTrash() {
        guard !isPreview else { status = "ゴミ箱を選択しました"; return }
        if !trashOpener(trashURL) { errorMessage = "ゴミ箱を開けませんでした。" }
    }

    func moveDroppedItemsToTrash(_ urls: [URL]) {
        guard !isPreview else { status = "ゴミ箱へ移動しました"; return }
        let failures = TrashDropService.move(urls, using: trashItemMover)
        if failures.isEmpty {
            status = "項目をゴミ箱へ移動しました。"
        } else {
            let details = failures.map { "\($0.name): \($0.message)" }.joined(separator: "\n")
            errorMessage = "次の項目をゴミ箱へ移動できませんでした。権限が不足している場合は、ファイルへのアクセスを許可してください。\n\(details)"
        }
        Task { await refreshTrash() }
    }
}
