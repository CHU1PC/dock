import Foundation

struct FinderSelectionRejection: Equatable {
    let name: String
    let reason: String
}

struct FinderSelectionCandidate: Equatable {
    let name: String
    let item: DockItem?
    let rejection: FinderSelectionRejection?

    static func resolve(_ url: URL, validate: (DockItem) -> String?) -> FinderSelectionCandidate {
        guard url.isFileURL else {
            return FinderSelectionCandidate(name: url.lastPathComponent, item: nil,
                                            rejection: FinderSelectionRejection(name: url.lastPathComponent, reason: "ローカル項目ではありません。"))
        }
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        guard let values = try? resolved.resourceValues(forKeys: [.isDirectoryKey]) else {
            return FinderSelectionCandidate(name: url.lastPathComponent, item: nil,
                                            rejection: FinderSelectionRejection(name: url.lastPathComponent, reason: "アクセスできないか、存在しません。"))
        }
        let isApplication = values.isDirectory == true && resolved.pathExtension.lowercased() == "app"
        let kind: DockItemKind = isApplication ? .application : values.isDirectory == true ? .folder : .file
        let item = DockItem(name: isApplication ? resolved.deletingPathExtension().lastPathComponent : resolved.lastPathComponent,
                            kind: kind, target: resolved.absoluteString)
        guard let reason = validate(item) else {
            return FinderSelectionCandidate(name: item.name, item: item, rejection: nil)
        }
        return FinderSelectionCandidate(name: item.name, item: nil,
                                        rejection: FinderSelectionRejection(name: item.name, reason: reason))
    }
}

struct FinderSelectionAddition: Equatable {
    let items: [DockItem]
    let rejected: [FinderSelectionRejection]

    static func prepare(_ candidates: [FinderSelectionCandidate]) -> FinderSelectionAddition {
        var items: [DockItem] = []
        var rejected: [FinderSelectionRejection] = []
        for candidate in candidates {
            if let rejection = candidate.rejection {
                rejected.append(rejection)
            } else if let item = candidate.item {
                items.append(item)
            }
        }
        return FinderSelectionAddition(items: items, rejected: rejected)
    }
}
