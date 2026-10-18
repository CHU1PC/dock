import XCTest
@testable import DockStudio

@MainActor
final class KeepRunningAppTests: XCTestCase {
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

    private func runningFinder() -> DockItem {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        return DockItem(name: "Finder", kind: .application, target: url.absoluteString, bundleIdentifier: "com.apple.finder")
    }

    private func makeStore(running item: DockItem) -> DockStore {
        let profile = DockProfile(name: "A", items: [])
        let store = DockStore(persistence: persistence,
                              initial: DockDocument(profiles: [profile], activeProfileID: profile.id))
        var settings = store.document.settings
        settings.showRunningApps = true
        store.updateSettings(settings)
        store.runningItems = [item]
        return store
    }

    func testKeepPersistsAndSurvivesReload() {
        let item = runningFinder()
        let store = makeStore(running: item)
        XCTAssertFalse(store.isPinned(item))

        XCTAssertTrue(store.keepInActiveProfile(item))

        XCTAssertTrue(store.isPinned(item))
        let saved = DockStore(persistence: persistence).activeProfile.items
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.bundleIdentifier, "com.apple.finder")
        XCTAssertEqual(saved.first?.target, item.target)
    }

    func testKeepingAlreadyKeptAppIsSilentNoOpReturningTrue() {
        let item = runningFinder()
        let store = makeStore(running: item)
        store.keepInActiveProfile(item)
        store.status = ""
        var again = item
        again.id = UUID()

        XCTAssertTrue(store.keepInActiveProfile(again))
        XCTAssertEqual(store.status, "")
        XCTAssertNil(store.errorMessage)

        XCTAssertEqual(store.activeProfile.items.count, 1)
        XCTAssertEqual(store.displayedItems.count, 1)
    }

    func testUnkeepFallsBackToTemporaryDisplayWhileRunning() {
        let item = runningFinder()
        let store = makeStore(running: item)
        store.keepInActiveProfile(item)

        store.removeFromActiveProfile(item)

        XCTAssertTrue(store.activeProfile.items.isEmpty)
        XCTAssertEqual(store.displayedItems.count, 1)
        XCTAssertFalse(store.isPinned(store.displayedItems[0]))
    }

    func testKeepRejectsInvalidApplicationAndNonApplication() {
        let store = makeStore(running: runningFinder())
        let missing = DockItem(name: "Gone", kind: .application, target: "file:///nonexistent/Gone.app",
                               bundleIdentifier: "com.example.gone")
        let noTarget = DockItem(name: "NoTarget", kind: .application, bundleIdentifier: "com.example.nt")
        let clock = DockItem(name: "Clock", kind: .clock)
        let before = store.document

        XCTAssertFalse(store.keepInActiveProfile(missing))
        XCTAssertTrue(store.errorMessage?.hasPrefix("Dock に保持できませんでした。") == true)
        XCTAssertFalse(store.keepInActiveProfile(noTarget))
        XCTAssertFalse(store.keepInActiveProfile(clock))
        XCTAssertEqual(store.document, before)
    }

    func testKeepAddsToUnsavedDraftWithoutLosingEdits() {
        let item = runningFinder()
        let store = makeStore(running: item)
        store.editorProfile.name = "Draft name"

        XCTAssertTrue(store.keepInActiveProfile(item))

        XCTAssertEqual(store.editorProfile.name, "Draft name")
        XCTAssertEqual(store.editorProfile.items.count, 1)
        XCTAssertTrue(store.saveProfile())
        XCTAssertEqual(store.activeProfile.items.count, 1)
    }
}
