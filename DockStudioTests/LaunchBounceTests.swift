import XCTest
@testable import DockStudio

@MainActor
final class LaunchBounceTests: XCTestCase {
    func testExistingDocumentsAndArchivesDefaultToBounceEnabled() throws {
        let document = DockStore.preview().document
        for original in [try JSONEncoder().encode(document), try JSONEncoder().encode(ProfileArchive(document: document))] {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
            var settings = try XCTUnwrap(json["settings"] as? [String: Any])
            settings.removeValue(forKey: "launchBounce")
            json["settings"] = settings
            let legacy = try JSONSerialization.data(withJSONObject: json)
            let restored = try ProfileArchive.decode(legacy)
            XCTAssertTrue(restored.settings.launchBounce)
            XCTAssertEqual(restored.settings.autoHide, document.settings.autoHide)
        }
    }

    func testBounceSettingPersistsAcrossRelaunchAndArchiveRestore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json"))
        let store = DockStore(persistence: persistence)
        for enabled in [false, true] {
            var settings = store.document.settings
            settings.launchBounce = enabled
            XCTAssertTrue(store.updateSettings(settings))
            XCTAssertEqual(DockStore(persistence: persistence).document.settings.launchBounce, enabled)
            let archive = try JSONEncoder().encode(ProfileArchive(document: store.document))
            XCTAssertEqual(try ProfileArchive.decode(archive).settings.launchBounce, enabled)
        }
    }

    func testLaunchStateEndsOnCompletionFailureAndTimeout() async throws {
        let store = DockStore.preview()
        let id = UUID()
        store.beginLaunch(id)
        XCTAssertTrue(store.launchingItemIDs.contains(id))
        var finished = false
        store.finishLaunch(id, when: { finished })
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(store.launchingItemIDs.contains(id))
        finished = true
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertFalse(store.launchingItemIDs.contains(id))

        store.beginLaunch(id)
        store.endLaunch(id)
        XCTAssertFalse(store.launchingItemIDs.contains(id))

        store.beginLaunch(id)
        store.finishLaunch(id, timeout: .milliseconds(200), when: { false })
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertFalse(store.launchingItemIDs.contains(id))
    }
}
