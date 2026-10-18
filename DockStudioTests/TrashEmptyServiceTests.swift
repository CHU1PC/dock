import XCTest
@testable import DockStudio

final class TrashEmptyServiceTests: XCTestCase {
    func testSuccessfulFinderRequestEmptiesTrash() {
        let service = TrashEmptyService(executeScript: { (nil, nil) })

        XCTAssertEqual(service.empty(), .emptied)
    }

    func testFinderCancellationIsNotAnError() {
        let service = TrashEmptyService(executeScript: { (-128, "User canceled") })

        XCTAssertEqual(service.empty(), .cancelled)
    }

    func testAutomationDenialHasDedicatedResult() {
        XCTAssertEqual(TrashEmptyService.result(errorNumber: -1743, message: "Not permitted"), .automationDenied)
    }

    func testOtherFinderErrorsKeepTheirMessage() {
        XCTAssertEqual(TrashEmptyService.result(errorNumber: -43, message: "Item not found"), .failed("Item not found"))
        XCTAssertEqual(TrashEmptyService.result(errorNumber: -43, message: nil), .failed("Finder でゴミ箱を空にできませんでした。"))
    }

    func testStoreReportsAutomationDenialAndStopsProcessing() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = await MainActor.run {
            let store = DockStore(persistence: ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json")))
            store.trashMonitor?.cancel()
            store.trashEmptyService = TrashEmptyService(executeScript: { (-1743, "Not permitted") })
            store.emptyTrash()
            return store
        }
        for _ in 0..<100 {
            if await MainActor.run(body: { !store.isEmptyingTrash }) { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        let message = await MainActor.run { store.errorMessage }
        let isProcessing = await MainActor.run { store.isEmptyingTrash }
        XCTAssertFalse(isProcessing)
        XCTAssertTrue(message?.contains("オートメーション") == true)
        XCTAssertTrue(message?.contains("Finder") == true)
    }
}
