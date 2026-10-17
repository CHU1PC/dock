import XCTest
@testable import DockStudio

@MainActor
final class DockIconSizeRangeTests: XCTestCase {
    func testRangeMatchesAppleTileSizeRange() {
        XCTAssertEqual(DockSettings.iconSizeRange.lowerBound, 16)
        XCTAssertEqual(DockSettings.iconSizeRange.upperBound, 128)
    }

    func testEndpointsPersistAcrossRelaunchAndArchiveRestore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json"))
        let store = DockStore(persistence: persistence)
        for size in [16.0, 40.0, 76.0, 128.0] {
            var settings = store.document.settings
            settings.iconSize = size
            XCTAssertTrue(store.updateSettings(settings))
            XCTAssertEqual(DockStore(persistence: persistence).document.settings.iconSize, size)
            let archive = try JSONEncoder().encode(ProfileArchive(document: store.document))
            XCTAssertEqual(try ProfileArchive.decode(archive).settings.iconSize, size)
        }
    }

    func testOutOfRangeSizesAreRejected() throws {
        let store = DockStore.preview()
        let original = store.document
        let persistence = ProfilePersistence(fileURL: URL(fileURLWithPath: "/unused"))
        for invalid in [15.99, 128.01, 0, -16, Double.infinity, -.infinity, .nan] {
            var settings = original.settings
            settings.iconSize = invalid
            XCTAssertFalse(store.updateSettings(settings))
            XCTAssertEqual(store.document, original)
            var document = original
            document.settings = settings
            XCTAssertThrowsError(try persistence.encode(document))
        }
    }

    func testLegacyDataWithOldRangeAndMissingFieldsStillLoads() throws {
        let document = DockStore.preview().document
        let persistence = ProfilePersistence(fileURL: URL(fileURLWithPath: "/unused"))
        for size in [40.0, 52.0, 76.0] {
            var sized = document
            sized.settings.iconSize = size
            for original in [try JSONEncoder().encode(sized), try JSONEncoder().encode(ProfileArchive(document: sized))] {
                var json = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
                var settings = try XCTUnwrap(json["settings"] as? [String: Any])
                settings.removeValue(forKey: "revealAnimationDuration")
                json["settings"] = settings
                let legacy = try JSONSerialization.data(withJSONObject: json)
                let restored = try ProfileArchive.decode(legacy)
                XCTAssertEqual(restored.settings.iconSize, size)
                XCTAssertEqual(restored.settings.revealAnimationDuration, 0.22)
                if json["formatVersion"] == nil {
                    XCTAssertEqual(try persistence.decode(legacy).settings.iconSize, size)
                }
            }
        }
    }

    func testSliderEditsStageValuesInsideTheRange() {
        let store = DockStore.preview()
        for size in [16.0, 128.0] {
            store.stageIconSize(size)
            XCTAssertEqual(store.effectiveIconSize, size)
            XCTAssertTrue(store.finishIconSizeEditing())
            XCTAssertEqual(store.document.settings.iconSize, size)
        }
    }
}
