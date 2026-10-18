import Foundation

struct DockSectionLayoutResult {
    let items: [DockItem]
    let dividerBefore: Set<Int>
}

enum DockSectionLayout {
    static func arrange(pinned: [DockItem], running: [DockItem], recent: [DockItem],
                        arrangement: DockArrangement) -> DockSectionLayoutResult {
        guard arrangement == .standardSections else {
            return DockSectionLayoutResult(items: pinned + running + recent, dividerBefore: [])
        }

        let pinnedApps = pinned.filter { !isDocument($0) }
        let pinnedDocuments = pinned.filter(isDocument)
        let runningApps = running.filter { !isDocument($0) }
        let sections = [pinnedApps + runningApps, recent, pinnedDocuments].filter { !$0.isEmpty }
        var result: [DockItem] = []
        var dividers = Set<Int>()
        for section in sections {
            if !result.isEmpty { dividers.insert(result.count) }
            result.append(contentsOf: section)
        }
        return DockSectionLayoutResult(items: result, dividerBefore: dividers)
    }

    static func insertionIndex(for item: DockItem, in items: [DockItem]) -> Int {
        guard isDocument(item) else {
            return items.lastIndex(where: { !isDocument($0) }).map { $0 + 1 } ?? 0
        }
        return items.lastIndex(where: isDocument).map { $0 + 1 } ?? items.count
    }

    private static func isDocument(_ item: DockItem) -> Bool {
        [.folder, .file, .link].contains(item.kind)
    }
}
