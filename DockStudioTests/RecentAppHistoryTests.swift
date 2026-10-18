import XCTest
@testable import DockStudio

@MainActor
final class RecentAppHistoryTests: XCTestCase {
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

    private func app(_ name: String) -> DockItem {
        DockItem(name: name, kind: .application, target: "file:///Applications/\(name).app",
                 bundleIdentifier: "com.example.\(name.lowercased())")
    }

    func testRecordingMovesApplicationToFrontAndRemovesDuplicates() {
        let first = app("First")
        let second = app("Second")

        let history = RecentAppHistory.recording(first, in: [second, first])

        XCTAssertEqual(history, [first, second])
    }

    func testVisibleItemsExcludePinnedAndRunningAppsAndStopAtThree() {
        let history = (1...6).map { app("App\($0)") }
        let excluded = Set([history[0].applicationIdentity!, history[2].applicationIdentity!])

        let visible = RecentAppHistory.visibleItems(history, excluding: excluded)

        XCTAssertEqual(visible.map(\.name), ["App2", "App4", "App5"])
    }

    func testDisplayedItemsCombinePinnedRunningAndRecentWithoutDuplicates() {
        let profile = DockProfile(name: "A", items: [app("Pinned")])
        let store = DockStore(persistence: persistence,
                              initial: DockDocument(profiles: [profile], activeProfileID: profile.id))
        var settings = store.document.settings
        settings.showRunningApps = true
        settings.showRecentApps = true
        XCTAssertTrue(store.updateSettings(settings))
        store.runningItems = [app("Running")]
        store.recordRecentApp(app("Recent1"))
        store.recordRecentApp(app("Recent2"))
        store.recordRecentApp(app("Running"))
        store.recordRecentApp(app("Pinned"))

        XCTAssertEqual(store.displayedItems.map(\.name), ["Pinned", "Running", "Recent2", "Recent1"])
    }

    func testRecentHistoryPersistsAndIsClearedWhenSettingTurnsOff() throws {
        let profile = DockProfile(name: "A", items: [])
        let store = DockStore(persistence: persistence,
                              initial: DockDocument(profiles: [profile], activeProfileID: profile.id))
        var settings = store.document.settings
        settings.showRecentApps = true
        XCTAssertTrue(store.updateSettings(settings))
        store.recordRecentApp(app("Recent"))

        let reloaded = DockStore(persistence: persistence)
        XCTAssertEqual(reloaded.recentAppItems.map(\.name), ["Recent"])

        var disabled = reloaded.document.settings
        disabled.showRecentApps = false
        XCTAssertTrue(reloaded.updateSettings(disabled))
        XCTAssertTrue(reloaded.recentAppItems.isEmpty)
        XCTAssertTrue(try RecentAppHistoryPersistence.load(from: try XCTUnwrap(reloaded.recentAppHistoryURL)).isEmpty)
    }

    func testLegacySettingsDefaultRecentAppsToDisabled() throws {
        let profile = DockProfile(name: "A", items: [])
        let document = DockDocument(profiles: [profile], activeProfileID: profile.id)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as? [String: Any])
        var settings = try XCTUnwrap(object["settings"] as? [String: Any])
        settings.removeValue(forKey: "showRecentApps")
        object["settings"] = settings
        let decoded = try ProfilePersistence(fileURL: persistence.fileURL)
            .decode(JSONSerialization.data(withJSONObject: object))

        XCTAssertFalse(decoded.settings.showRecentApps)
    }
}
