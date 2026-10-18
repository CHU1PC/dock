import Foundation

enum DockDropTarget {
    case insertion(Int)
    case application(DockItem)
    case folder(URL?)
    case trash
}

enum DockDropDecision: Equatable {
    case insert(at: Int)
    case moveIntoFolder(URL)
    case openWithApplication(DockItem)
    case moveToTrash
    case refuse(String)
}

enum DockDropRouting {
    static func applicationTarget(at point: CGPoint, items: [DockItem], frames: [UUID: CGRect]) -> DockItem? {
        items.first { item in
            item.kind == .application && frames[item.id]?.contains(point) == true
        }
    }

    static func decision(for target: DockDropTarget, source: URL? = nil,
                         folderIsAvailable: Bool = true) -> DockDropDecision {
        switch target {
        case .insertion(let index):
            return .insert(at: index)
        case .application(let item):
            return .openWithApplication(item)
        case .trash:
            return .moveToTrash
        case .folder(let folderURL):
            guard folderIsAvailable, let folderURL, folderURL.isFileURL else {
                return .refuse("フォルダを利用できません。")
            }
            if let source, isFolder(source), contains(source, folderURL) {
                return .refuse("フォルダ自身またはその子孫への移動はできません。")
            }
            return .moveIntoFolder(folderURL)
        }
    }

    private static func isFolder(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func contains(_ parent: URL, _ child: URL) -> Bool {
        let parentPath = parent.standardizedFileURL.resolvingSymlinksInPath().path
        let childPath = child.standardizedFileURL.resolvingSymlinksInPath().path
        return childPath == parentPath || childPath.hasPrefix(parentPath.hasSuffix("/") ? parentPath : parentPath + "/")
    }
}

struct FolderDropFailure: Equatable {
    let name: String
    let message: String
}

enum FolderDropService {
    static func move(_ urls: [URL], into folder: URL,
                     using moveItem: (URL, URL) throws -> Void) -> [FolderDropFailure] {
        urls.compactMap { url in
            do {
                try moveItem(url, folder.appendingPathComponent(url.lastPathComponent))
                return nil
            } catch {
                return FolderDropFailure(name: url.lastPathComponent, message: error.localizedDescription)
            }
        }
    }
}
