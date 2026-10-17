import XCTest
@testable import DockStudio

@MainActor
final class RemoveDockItemTests: XCTestCase {
    private var directory: URL!
    private var persistence: ProfilePersistence!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        persistence = ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json"))
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testRemovalPersistsAndKeepsOriginalFile() throws {
        let file = directory.appendingPathComponent("keep.txt")
        try "data".write(to: file, atomically: true, encoding: .utf8)
        let item = DockItem(name: "keep", kind: .file, target: file.absoluteString)
        let store = DockStore(persistence: persistence)
        store.addItem(item)
        XCTAssertTrue(store.saveProfile())
        let other = store.activeProfile.items.filter { $0.id != item.id }

        XCTAssertTrue(store.removeSavedItem(item.id, fromProfile: store.document.activeProfileID))

        XCTAssertFalse(store.isPinned(item))
        XCTAssertEqual(store.activeProfile.items, other)
        XCTAssertFalse(DockStore(persistence: persistence).activeProfile.items.contains { $0.id == item.id })
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testRemovalDropsItemFromUnsavedDraftButKeepsOtherEdits() {
        let item = DockItem(name: "Clock", kind: .clock)
        let store = DockStore(persistence: persistence)
        store.addItem(item)
        XCTAssertTrue(store.saveProfile())
        store.editorProfile.name = "Draft name"
        XCTAssertTrue(store.removeSavedItem(item.id, fromProfile: store.editingProfileID))
        XCTAssertFalse(store.editorProfile.items.contains { $0.id == item.id })
        XCTAssertEqual(store.editorProfile.name, "Draft name")

        let reloaded = DockStore(persistence: persistence)
        XCTAssertFalse(reloaded.editorProfile.items.contains { $0.id == item.id })
        XCTAssertEqual(reloaded.editorProfile.name, "Draft name")
    }

    func testRemovalFromInactiveProfileLeavesActiveProfileUntouched() {
        let target = DockItem(name: "Clock", kind: .clock)
        let keep = DockItem(name: "Timer", kind: .focusTimer)
        let active = DockProfile(name: "A", items: [keep])
        let inactive = DockProfile(name: "B", items: [target, keep])
        let store = DockStore(persistence: persistence,
                              initial: DockDocument(profiles: [active, inactive], activeProfileID: active.id))

        XCTAssertTrue(store.removeSavedItem(target.id, fromProfile: inactive.id))

        XCTAssertEqual(store.document.profiles.first { $0.id == active.id }?.items, [keep])
        XCTAssertEqual(store.document.profiles.first { $0.id == inactive.id }?.items, [keep])
    }

    func testRemovalClearsEditorUndoBufferForSameItem() {
        let item = DockItem(name: "Clock", kind: .clock)
        let store = DockStore(persistence: persistence)
        store.addItem(item)
        XCTAssertTrue(store.saveProfile())
        store.removeItem(item.id)
        XCTAssertTrue(store.canUndoRemoval)

        XCTAssertTrue(store.removeSavedItem(item.id, fromProfile: store.document.activeProfileID))

        XCTAssertFalse(store.canUndoRemoval)
        store.undoRemoval()
        XCTAssertFalse(store.editorProfile.items.contains { $0.id == item.id })
    }

    func testRemovalFailsAndKeepsDocumentWhenStorageIsReadOnly() throws {
        try "not json".write(to: persistence.fileURL, atomically: true, encoding: .utf8)
        let item = DockItem(name: "Clock", kind: .clock)
        let profile = DockProfile(name: "A", items: [item])
        let store = DockStore(persistence: persistence,
                              initial: DockDocument(profiles: [profile], activeProfileID: profile.id))
        let before = store.document

        XCTAssertFalse(store.removeSavedItem(item.id, fromProfile: profile.id))

        XCTAssertEqual(store.document, before)
    }

    func testRunningAppNotInProfileIsNotRemovable() {
        var settings = DockSettings()
        settings.showRunningApps = true
        let store = DockStore(persistence: persistence)
        store.updateSettings(settings)
        let running = DockItem(name: "Running", kind: .application, bundleIdentifier: "com.example.running")
        store.runningItems = [running]
        let before = store.document

        XCTAssertTrue(store.displayedItems.contains { $0.id == running.id })
        XCTAssertFalse(store.isPinned(running))
        XCTAssertFalse(store.removeSavedItem(running.id, fromProfile: store.document.activeProfileID))
        XCTAssertEqual(store.document, before)
    }
}
