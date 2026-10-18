import AppKit

struct FolderContentsCandidate: Equatable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isApplication: Bool
    let bundleIdentifier: String?
}

enum FolderContentsModel {
    static func items(from candidates: [FolderContentsCandidate]) -> [DockItem] {
        candidates.map { candidate in
            let kind: DockItemKind = candidate.isApplication ? .application : candidate.isDirectory ? .folder : .file
            return DockItem(name: candidate.name, kind: kind, target: candidate.url.absoluteString,
                            bundleIdentifier: candidate.bundleIdentifier)
        }
    }
}

enum FolderStackIconModel {
    static let previewLimit = 3

    enum State: Equatable {
        case loading, empty, failed
        case preview([DockItem])
    }

    static func previewItems(from contents: [DockItem]) -> [DockItem] {
        Array(contents.prefix(previewLimit))
    }

    static func state(contents: [DockItem]?, failedToRead: Bool) -> State {
        if failedToRead { return .failed }
        guard let contents else { return .loading }
        let items = previewItems(from: contents)
        return items.isEmpty ? .empty : .preview(items)
    }
}

enum FolderContentsReader {
    static func read(at url: URL, fileManager: FileManager = .default) throws -> [DockItem] {
        let children = try fileManager.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: []
        )
        let candidates = children.map { child -> FolderContentsCandidate in
            let resolved = child.resolvingSymlinksInPath()
            let values = try? resolved.resourceValues(forKeys: [.isDirectoryKey])
            let isApplication = resolved.pathExtension.lowercased() == "app"
                && values?.isDirectory == true
                && Bundle(url: resolved)?.bundleIdentifier != nil
            return FolderContentsCandidate(
                url: child,
                name: child.lastPathComponent,
                isDirectory: values?.isDirectory == true,
                isApplication: isApplication,
                bundleIdentifier: isApplication ? Bundle(url: resolved)?.bundleIdentifier : nil
            )
        }
        return FolderContentsModel.items(from: candidates)
    }
}
