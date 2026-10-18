import XCTest
@testable import DockStudio

final class TrashDropTests: XCTestCase {
    func testMovesOnlyDroppedItemsUsingTrashOperation() {
        let dropped = [URL(fileURLWithPath: "/tmp/first.txt"), URL(fileURLWithPath: "/tmp/second.txt")]
        var moved: [URL] = []

        let failures = TrashDropService.move(dropped) { moved.append($0) }

        XCTAssertTrue(failures.isEmpty)
        XCTAssertEqual(moved, dropped)
    }

    func testReportsFailuresAndContinuesMovingRemainingItems() {
        enum MoveError: LocalizedError {
            case denied
            var errorDescription: String? { "Permission denied" }
        }
        let first = URL(fileURLWithPath: "/tmp/locked.txt")
        let second = URL(fileURLWithPath: "/tmp/allowed.txt")
        let third = URL(fileURLWithPath: "/Volumes/Read Only/blocked.txt")
        var attempted: [URL] = []

        let failures = TrashDropService.move([first, second, third]) { url in
            attempted.append(url)
            if url == first || url == third { throw MoveError.denied }
        }

        XCTAssertEqual(attempted, [first, second, third])
        XCTAssertEqual(failures, [
            TrashDropFailure(name: "locked.txt", message: "Permission denied"),
            TrashDropFailure(name: "blocked.txt", message: "Permission denied")
        ])
    }

    @MainActor
    func testStoreShowsPermissionGuidanceForFailedDrop() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DockStore(persistence: ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json")))
        store.trashMonitor?.cancel()
        store.trashItemMover = { _ in throw CocoaError(.fileWriteNoPermission) }

        store.moveDroppedItemsToTrash([URL(fileURLWithPath: "/tmp/blocked.txt")])

        XCTAssertTrue(store.errorMessage?.contains("blocked.txt") == true)
        XCTAssertTrue(store.errorMessage?.contains("権限が不足している場合") == true)
    }
}
