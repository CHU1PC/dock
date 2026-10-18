import Foundation

enum DockItemReordering {
    static func insertionIndex(at point: CGPoint, frames: [CGRect], vertical: Bool) -> Int {
        frames.firstIndex { vertical ? point.y < $0.midY : point.x < $0.midX } ?? frames.count
    }

    static func reorderedItems(savedItems: [DockItem], displayedItems: [DockItem],
                               dividerBefore: Set<Int>, movingID: UUID,
                               insertionIndex: Int) -> [DockItem]? {
        guard let sourceIndex = savedItems.firstIndex(where: { $0.id == movingID }),
              let destination = newIndex(savedItems: savedItems, displayedItems: displayedItems,
                                        dividerBefore: dividerBefore, movingID: movingID,
                                        insertionIndex: insertionIndex) else { return nil }
        var result = savedItems
        let moving = result.remove(at: sourceIndex)
        result.insert(moving, at: min(max(destination, 0), result.count))
        return result
    }

    static func newIndex(savedItems: [DockItem], displayedItems: [DockItem],
                         dividerBefore: Set<Int>, movingID: UUID,
                         insertionIndex: Int) -> Int? {
        guard let sourceIndex = savedItems.firstIndex(where: { $0.id == movingID }),
              let displayedSourceIndex = displayedItems.firstIndex(where: { $0.id == movingID }),
              let target = clampedInsertionIndex(displayedItems: displayedItems,
                                                 dividerBefore: dividerBefore,
                                                 movingID: movingID,
                                                 insertionIndex: insertionIndex) else { return nil }

        let sectionStart = dividerBefore.filter { $0 < displayedSourceIndex }.max() ?? 0
        let displayedWithoutMoving = displayedItems.enumerated().compactMap { index, item in
            index == displayedSourceIndex ? nil : item
        }
        let savedIDs = Set(savedItems.map(\.id))

        let previous = displayedWithoutMoving[..<min(target, displayedWithoutMoving.count)]
            .reversed().first { savedIDs.contains($0.id) }
        let next = displayedWithoutMoving.dropFirst(min(target, displayedWithoutMoving.count))
            .first { savedIDs.contains($0.id) }

        let savedWithoutMoving = savedItems.enumerated().compactMap { index, item in
            index == sourceIndex ? nil : item
        }
        if let previous, let index = savedWithoutMoving.firstIndex(where: { $0.id == previous.id }) {
            return index + 1
        } else if let next, let index = savedWithoutMoving.firstIndex(where: { $0.id == next.id }) {
            return index
        }
        return min(max(target, 0), savedWithoutMoving.count)
    }

    static func clampedInsertionIndex(displayedItems: [DockItem], dividerBefore: Set<Int>,
                                      movingID: UUID, insertionIndex: Int) -> Int? {
        guard let sourceIndex = displayedItems.firstIndex(where: { $0.id == movingID }) else { return nil }
        let sectionStart = dividerBefore.filter { $0 < sourceIndex }.max() ?? 0
        let sectionEnd = dividerBefore.filter { $0 > sourceIndex }.min() ?? displayedItems.count
        let startAfterRemoval = sectionStart
        let endAfterRemoval = sectionEnd - 1
        return min(max(insertionIndex, startAfterRemoval), endAfterRemoval)
    }
}
