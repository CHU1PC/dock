import XCTest
@testable import DockStudio

final class DockItemReorderingTests: XCTestCase {
    private func item(_ name: String) -> DockItem {
        DockItem(name: name, kind: .spacer)
    }

    func testNewIndexSupportsFirstAndLastPositions() {
        let items = [item("A"), item("B"), item("C")]
        let displayed = items

        XCTAssertEqual(DockItemReordering.newIndex(savedItems: items, displayedItems: displayed,
                                                   dividerBefore: [], movingID: items[2].id,
                                                   insertionIndex: 0), 0)
        XCTAssertEqual(DockItemReordering.newIndex(savedItems: items, displayedItems: displayed,
                                                   dividerBefore: [], movingID: items[0].id,
                                                   insertionIndex: 2), 2)
    }

    func testDroppingAtOriginalPositionPreservesOrder() {
        let items = [item("A"), item("B"), item("C")]

        let reordered = DockItemReordering.reorderedItems(savedItems: items, displayedItems: items,
                                                           dividerBefore: [], movingID: items[1].id,
                                                           insertionIndex: 1)

        XCTAssertEqual(reordered, items)
    }

    func testRunningAndRecentItemsDoNotBecomeSavedReorderTargets() {
        let first = item("Pinned first")
        let second = item("Pinned second")
        let running = DockItem(name: "Running", kind: .application, target: "file:///Applications/Running.app/")
        let recent = item("Recent")
        let displayed = [first, running, second, recent]

        XCTAssertEqual(DockItemReordering.clampedInsertionIndex(displayedItems: displayed,
                                                                dividerBefore: [3], movingID: first.id,
                                                                insertionIndex: 3), 2)
        let newIndex = DockItemReordering.newIndex(savedItems: [first, second], displayedItems: displayed,
                                                   dividerBefore: [3], movingID: first.id,
                                                   insertionIndex: 3)
        let reordered = DockItemReordering.reorderedItems(savedItems: [first, second], displayedItems: displayed,
                                                           dividerBefore: [3], movingID: first.id,
                                                           insertionIndex: 3)

        XCTAssertEqual(newIndex, 1)
        XCTAssertEqual(reordered?.map(\.name), ["Pinned second", "Pinned first"])
    }

    @MainActor
    func testSuccessfulReorderPersistsNewOrder() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json"))
        var document = DockStore.initialDocument()
        let items = [item("A"), item("B"), item("C")]
        document.profiles[0].items = items
        try persistence.save(document)
        let store = DockStore(persistence: persistence)
        let layout = DockSectionLayout.arrange(pinned: items, running: [], recent: [], arrangement: .free)

        XCTAssertTrue(store.reorderActiveItem(items[0].id, insertionIndex: 2,
                                              displayedItems: layout.items,
                                              dividerBefore: layout.dividerBefore))
        XCTAssertEqual(store.activeProfile.items.map(\.name), ["B", "C", "A"])
        XCTAssertEqual(DockStore(persistence: persistence).activeProfile.items.map(\.name), ["B", "C", "A"])
    }

    @MainActor
    func testFailedSaveLeavesOriginalOrder() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json"))
        let store = DockStore(persistence: persistence)
        let items = [item("A"), item("B"), item("C")]
        var document = store.document
        document.profiles[0].items = items
        try persistence.save(document)
        let loadedStore = DockStore(persistence: persistence)
        let original = loadedStore.activeProfile.items

        try FileManager.default.removeItem(at: persistence.fileURL)
        try FileManager.default.createDirectory(at: persistence.fileURL, withIntermediateDirectories: true)
        let layout = DockSectionLayout.arrange(pinned: original, running: [], recent: [], arrangement: .free)

        XCTAssertFalse(loadedStore.reorderActiveItem(original[0].id, insertionIndex: 2,
                                                      displayedItems: layout.items,
                                                      dividerBefore: layout.dividerBefore))
        XCTAssertEqual(loadedStore.activeProfile.items, original)
        XCTAssertNotNil(loadedStore.errorMessage)
    }
}
