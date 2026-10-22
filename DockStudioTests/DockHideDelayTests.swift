import XCTest
@testable import DockStudio

@MainActor
final class DockHideDelayTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testDefaultMatchesPreviousBehaviorOfOneSecond() {
        XCTAssertEqual(DockSettings().hideDelay, 1.0)
        XCTAssertFalse(DockVisibilityState.hasHideDelayElapsed(since: start, now: start.addingTimeInterval(0.99), delay: DockSettings.defaultHideDelay))
        XCTAssertTrue(DockVisibilityState.hasHideDelayElapsed(since: start, now: start.addingTimeInterval(1), delay: DockSettings.defaultHideDelay))
    }

    func testZeroDelayHidesImmediately() {
        XCTAssertTrue(DockVisibilityState.hasHideDelayElapsed(since: start, now: start, delay: 0))
    }

    func testUpperBoundWaitsFiveSeconds() {
        XCTAssertFalse(DockVisibilityState.hasHideDelayElapsed(since: start, now: start.addingTimeInterval(4.9), delay: 5))
        XCTAssertTrue(DockVisibilityState.hasHideDelayElapsed(since: start, now: start.addingTimeInterval(5), delay: 5))
    }

    func testInvalidDelaysNeverHide() {
        for invalid in [-0.1, 5.1, Double.infinity, -.infinity, .nan] {
            XCTAssertFalse(DockVisibilityState.hasHideDelayElapsed(since: start, now: start.addingTimeInterval(100), delay: invalid))
        }
    }

    func testStateCollapsesAfterConfiguredDelay() {
        var state = DockVisibilityState()
        state.update(visible: true, autoHide: true, hovering: false, interacting: false, hideDelay: 3, now: start)
        state.update(visible: true, autoHide: true, hovering: false, interacting: false, hideDelay: 3, now: start.addingTimeInterval(2.9))
        XCTAssertFalse(state.isCollapsed)
        state.update(visible: true, autoHide: true, hovering: false, interacting: false, hideDelay: 3, now: start.addingTimeInterval(3))
        XCTAssertTrue(state.isCollapsed)
    }

    func testOldSavedDataLoadsWithDefaultDelay() throws {
        let data = try JSONEncoder().encode(ProfileArchive(document: DockStore.preview().document))
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var settings = try XCTUnwrap(root["settings"] as? [String: Any])
        XCTAssertNotNil(settings["hideDelay"])
        settings.removeValue(forKey: "hideDelay")
        root["settings"] = settings
        let old = try JSONSerialization.data(withJSONObject: root)
        XCTAssertEqual(try ProfileArchive.decode(old).settings.hideDelay, 1.0)
    }

    func testEndpointsPersistAndInvalidValuesAreRejected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json"))
        let store = DockStore(persistence: persistence)
        for delay in [0.0, 1.0, 5.0] {
            var settings = store.document.settings
            settings.hideDelay = delay
            XCTAssertTrue(store.updateSettings(settings))
            XCTAssertEqual(DockStore(persistence: persistence).document.settings.hideDelay, delay)
        }
        let original = store.document
        for invalid in [-0.1, 5.1, Double.infinity, .nan] {
            var settings = original.settings
            settings.hideDelay = invalid
            XCTAssertFalse(store.updateSettings(settings))
            XCTAssertEqual(store.document, original)
        }
    }

    func testSliderStagesRoundedClampedValueUntilFinished() {
        let store = DockStore.preview()
        store.stageHideDelay(2.26)
        XCTAssertEqual(store.effectiveHideDelay, 2.3)
        XCTAssertEqual(store.document.settings.hideDelay, 1.0)
        XCTAssertTrue(store.finishHideDelayEditing())
        XCTAssertEqual(store.document.settings.hideDelay, 2.3)
        store.stageHideDelay(9)
        XCTAssertTrue(store.finishHideDelayEditing())
        XCTAssertEqual(store.document.settings.hideDelay, 5)
        store.stageHideDelay(.nan)
        XCTAssertNil(store.transientHideDelay)
    }
}
