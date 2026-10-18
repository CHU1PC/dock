import Foundation

extension DockStore {
    @discardableResult
    func reorderActiveItem(_ id: UUID, insertionIndex: Int,
                          displayedItems: [DockItem], dividerBefore: Set<Int>) -> Bool {
        guard !storageIsReadOnly,
              let profileIndex = document.profiles.firstIndex(where: { $0.id == document.activeProfileID }),
              let reordered = DockItemReordering.reorderedItems(
                savedItems: document.profiles[profileIndex].items,
                displayedItems: displayedItems,
                dividerBefore: dividerBefore,
                movingID: id,
                insertionIndex: insertionIndex
              ), reordered != document.profiles[profileIndex].items else { return false }

        var candidate = document
        candidate.profiles[profileIndex].items = reordered
        guard commit(candidate) else { return false }
        let newIndex = reordered.firstIndex { $0.id == id } ?? 0
        status = "\(reordered[newIndex].name) を\(newIndex + 1)番目に移動しました"
        return true
    }
}
