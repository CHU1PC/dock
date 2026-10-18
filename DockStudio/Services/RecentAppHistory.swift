import Foundation

enum RecentAppHistory {
    static let maximumStoredItems = 50
    static let maximumVisibleItems = 3

    static func recording(_ item: DockItem, in history: [DockItem]) -> [DockItem] {
        guard item.kind == .application, let identity = item.applicationIdentity else { return history }
        var items = [item]
        var seen: Set<String> = [identity]
        for existing in history where items.count < maximumStoredItems {
            guard existing.kind == .application, let existingIdentity = existing.applicationIdentity,
                  seen.insert(existingIdentity).inserted else { continue }
            items.append(existing)
        }
        return items
    }

    static func visibleItems(_ history: [DockItem], excluding excludedIdentities: Set<String>) -> [DockItem] {
        var seen = excludedIdentities
        var result: [DockItem] = []
        for item in history {
            guard item.kind == .application, let identity = item.applicationIdentity,
                  seen.insert(identity).inserted else { continue }
            result.append(item)
            if result.count == maximumVisibleItems { break }
        }
        return result
    }
}

enum RecentAppHistoryPersistence {
    static func load(from url: URL) throws -> [DockItem] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let items = try JSONDecoder().decode([DockItem].self, from: Data(contentsOf: url))
        return Array(RecentAppHistory.recordingAll(items).prefix(RecentAppHistory.maximumStoredItems))
    }

    static func save(_ items: [DockItem], to url: URL) throws {
        let history = Array(RecentAppHistory.recordingAll(items).prefix(RecentAppHistory.maximumStoredItems))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(history).write(to: url, options: .atomic)
    }

    static func clear(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try save([], to: url)
    }
}

private extension RecentAppHistory {
    static func recordingAll(_ items: [DockItem]) -> [DockItem] {
        var seen: Set<String> = []
        return items.filter { item in
            guard item.kind == .application, let identity = item.applicationIdentity else { return false }
            return seen.insert(identity).inserted
        }
    }
}
