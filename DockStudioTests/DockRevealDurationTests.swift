import XCTest
@testable import DockStudio

@MainActor
final class DockRevealDurationTests: XCTestCase {
    func testExistingDocumentsAndArchivesDefaultToCurrentRevealDuration() throws {
        let document = DockStore.preview().document
        let persistence = ProfilePersistence(fileURL: URL(fileURLWithPath: "/unused"))
        for original in [try JSONEncoder().encode(document), try JSONEncoder().encode(ProfileArchive(document: document))] {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
            var settings = try XCTUnwrap(json["settings"] as? [String: Any])
            settings.removeValue(forKey: "revealAnimationDuration")
            json["settings"] = settings
            let legacy = try JSONSerialization.data(withJSONObject: json)
            let restored = try ProfileArchive.decode(legacy)
            XCTAssertEqual(restored.settings.revealAnimationDuration, 0.22)
            XCTAssertEqual(restored.settings.autoHide, document.settings.autoHide)
            if json["formatVersion"] == nil {
                XCTAssertEqual(try persistence.decode(legacy).settings, document.settings)
            }
        }
    }

    func testDurationEndpointsPersistAcrossRelaunchAndArchiveRestore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json"))
        let store = DockStore(persistence: persistence)
        for duration in [0.0, 0.22, 1.0] {
            var settings = store.document.settings
            settings.autoHide = true
            settings.revealAnimationDuration = duration
            XCTAssertTrue(store.updateSettings(settings))
            let reloaded = DockStore(persistence: persistence)
            XCTAssertEqual(reloaded.document.settings, settings)
            let archive = try JSONEncoder().encode(ProfileArchive(document: store.document))
            XCTAssertEqual(try ProfileArchive.decode(archive).settings, settings)
            reloaded.activateProfile(reloaded.document.profiles[1].id)
            XCTAssertEqual(reloaded.document.settings.revealAnimationDuration, duration)
        }
    }

    func testInvalidDurationsCannotReplaceSavedSettingsOrEnterFromArchives() throws {
        let store = DockStore.preview()
        let original = store.document
        let persistence = ProfilePersistence(fileURL: URL(fileURLWithPath: "/unused"))
        for invalid in [-0.01, 1.01, Double.infinity, -.infinity, .nan] {
            var settings = original.settings
            settings.revealAnimationDuration = invalid
            XCTAssertFalse(store.updateSettings(settings))
            XCTAssertEqual(store.document, original)
            var document = original
            document.settings = settings
            XCTAssertThrowsError(try persistence.encode(document))
            if invalid.isFinite {
                let archive = try JSONEncoder().encode(ProfileArchive(document: document))
                XCTAssertThrowsError(try ProfileArchive.decode(archive))
            }
        }
    }

}
