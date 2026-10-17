import AppKit

extension DockStore {
    static let trashItem = DockItem(id: UUID(uuidString: "7A5C0000-0000-4000-8000-000000000001")!,
                                    name: "ゴミ箱", kind: .folder)

    var trashURL: URL {
        (try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
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
}
