import XCTest
@testable import DockStudio

final class DockSectionLayoutTests: XCTestCase {
    private func item(_ name: String, _ kind: DockItemKind) -> DockItem {
        DockItem(name: name, kind: kind, target: kind == .application ? "file:///Applications/\(name).app" : nil)
    }

    func testStandardSectionsKeepEachGroupOrderAndPutRecentsBetweenAppsAndDocuments() {
        let pinned = [item("Folder", .folder), item("App 1", .application), item("File", .file), item("App 2", .application)]
        let running = [item("Running", .application)]
        let recent = [item("Recent", .application)]

        let result = DockSectionLayout.arrange(pinned: pinned, running: running, recent: recent,
                                               arrangement: .standardSections)

        XCTAssertEqual(result.items.map(\.name), ["App 1", "App 2", "Running", "Recent", "Folder", "File"])
        XCTAssertEqual(result.dividerBefore, [3, 4])
    }

    func testFreeArrangementLeavesAllItemsInSavedDisplayOrderWithoutBoundaries() {
        let pinned = [item("Folder", .folder), item("App", .application)]
        let running = [item("Running", .application)]
        let recent = [item("Recent", .application)]

        let result = DockSectionLayout.arrange(pinned: pinned, running: running, recent: recent,
                                               arrangement: .free)

        XCTAssertEqual(result.items.map(\.name), ["Folder", "App", "Running", "Recent"])
        XCTAssertTrue(result.dividerBefore.isEmpty)
    }

    func testDroppedApplicationsAndDocumentsTargetTheirSectionEnds() {
        let items = [item("Folder", .folder), item("App 1", .application), item("File", .file), item("App 2", .application)]

        XCTAssertEqual(DockSectionLayout.insertionIndex(for: item("New App", .application), in: items), 4)
        XCTAssertEqual(DockSectionLayout.insertionIndex(for: item("New Folder", .folder), in: items), 3)
    }

    func testLegacySettingsKeepFreeArrangementAndSavedItemOrder() throws {
        let items = [item("Folder", .folder), item("App", .application)]
        let profile = DockProfile(name: "Legacy", items: items)
        let document = DockDocument(profiles: [profile], activeProfileID: profile.id)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as? [String: Any])
        var settings = try XCTUnwrap(object["settings"] as? [String: Any])
        settings.removeValue(forKey: "arrangement")
        object["settings"] = settings

        let decoded = try JSONDecoder().decode(DockDocument.self, from: JSONSerialization.data(withJSONObject: object))

        XCTAssertEqual(decoded.settings.arrangement, .free)
        XCTAssertEqual(decoded.profiles[0].items.map(\.name), ["Folder", "App"])
    }
}
