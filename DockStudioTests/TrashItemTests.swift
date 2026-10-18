import XCTest
@testable import DockStudio

@MainActor
final class TrashItemTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.appendingPathComponent("denied").path)
        try FileManager.default.removeItem(at: root)
    }

    private func directory(_ name: String, files: [String] = []) throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for file in files { try Data().write(to: url.appendingPathComponent(file)) }
        return url
    }

    private func state(_ urls: [URL]) -> TrashState { TrashInspector(locations: { urls }).state() }

    func testEmptyAndMissingDirectoriesAreEmpty() throws {
        let empty = try directory("empty", files: [".DS_Store"])
        XCTAssertEqual(state([empty]), .empty)
        XCTAssertEqual(state([root.appendingPathComponent("missing")]), .empty)
    }

    func testAnyVolumeWithItemsMakesTrashFull() throws {
        let empty = try directory("empty")
        let full = try directory("full", files: ["a.txt"])
        XCTAssertEqual(state([empty, full]), .hasItems)
        XCTAssertEqual(state([full, empty]), .hasItems)
    }

    func testHiddenTrashedFileCountsAsItem() throws {
        XCTAssertEqual(state([try directory("hidden", files: [".profile"])]), .hasItems)
    }

    func testUnreadableLocationIsNeverReportedEmpty() throws {
        let denied = try directory("denied")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: denied.path)
        let empty = try directory("empty")
        let full = try directory("full", files: ["a.txt"])
        XCTAssertEqual(state([denied]), .unknown)
        XCTAssertEqual(state([denied, empty]), .unknown)
        XCTAssertEqual(state([denied, full]), .hasItems)
    }

    func testRefreshReflectsChanges() async throws {
        let trash = try directory("trash")
        let store = DockStore(persistence: nil)
        store.trashInspector = TrashInspector(locations: { [trash] })
        await store.refreshTrash()
        XCTAssertEqual(store.trashState, .empty)
        try Data().write(to: trash.appendingPathComponent("a.txt"))
        await store.refreshTrash()
        XCTAssertEqual(store.trashState, .hasItems)
        try FileManager.default.removeItem(at: trash.appendingPathComponent("a.txt"))
        await store.refreshTrash()
        XCTAssertEqual(store.trashState, .empty)
    }

    func testOpenTrashOpensTrashDirectoryAndReportsFailure() {
        var opened: [URL] = []
        let preview = DockStore(persistence: nil)
        preview.trashOpener = { opened.append($0); return true }
        preview.openTrash()
        XCTAssertTrue(opened.isEmpty)

        let live = DockStore(persistence: ProfilePersistence(fileURL: root.appendingPathComponent("p.json")))
        live.trashOpener = { opened.append($0); return false }
        live.openTrash()
        XCTAssertEqual(opened, [live.trashURL])
        XCTAssertEqual(live.trashURL.lastPathComponent, ".Trash")
        XCTAssertNotNil(live.errorMessage)
    }

    func testTrashIsNotAProfileItem() {
        let store = DockStore(persistence: nil)
        XCTAssertFalse(store.displayedItems.contains { $0.id == DockStore.trashItem.id })
        XCTAssertFalse(store.isPinned(DockStore.trashItem))
    }

    func testStoreIsReleasedWhileMonitoringTrash() async throws {
        weak var released: DockStore?
        do {
            let store = DockStore(persistence: ProfilePersistence(fileURL: root.appendingPathComponent("m.json")))
            XCTAssertNotNil(store.trashMonitor)
            released = store
        }
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(released)
    }
}
