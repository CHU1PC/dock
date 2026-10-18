import Foundation

extension DockStore {
    func moveDroppedItemsIntoFolder(_ urls: [URL], at folderURL: URL?) {
        guard !urls.isEmpty else { errorMessage = "移動するファイルを読み込めませんでした。"; return }
        let available = folderURL.map(Self.isAvailableFolder) ?? false
        guard case .moveIntoFolder(let destination) = DockDropRouting.decision(
            for: .folder(folderURL), folderIsAvailable: available
        ) else {
            errorMessage = "ドロップ先のフォルダを利用できません。"
            return
        }
        guard !isPreview else { status = "フォルダへ移動しました"; return }

        var failures: [FolderDropFailure] = []
        var refused: [String] = []
        for url in urls where url.isFileURL {
            switch DockDropRouting.decision(for: .folder(destination), source: url) {
            case .moveIntoFolder:
                failures += FolderDropService.move([url], into: destination) { source, target in
                    try FileManager.default.moveItem(at: source, to: target)
                }
            case .refuse(let reason):
                refused.append("\(url.lastPathComponent): \(reason)")
            case .insert, .openWithApplication, .moveToTrash:
                continue
            }
        }

        if failures.isEmpty && refused.isEmpty {
            status = "\(urls.count) 個の項目をフォルダへ移動しました。"
        } else {
            let details = failures.map { "\($0.name): \($0.message)" } + refused
            errorMessage = "次の項目をフォルダへ移動できませんでした。\n\(details.joined(separator: "\n"))"
        }
    }

    private static func isAvailableFolder(_ url: URL) -> Bool {
        guard url.isFileURL,
              let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) else { return false }
        return values.isDirectory == true
    }
}
