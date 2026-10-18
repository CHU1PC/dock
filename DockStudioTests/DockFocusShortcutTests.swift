import XCTest
@testable import DockStudio

final class DockFocusShortcutTests: XCTestCase {
    func testShortcutPresetsUseDistinctLabelsAndKeyCodes() {
        XCTAssertEqual(Set(DockFocusShortcut.allCases.map(\.title)).count, DockFocusShortcut.allCases.count)
        XCTAssertEqual(Set(DockFocusShortcut.allCases.map(\.keyCode)).count, DockFocusShortcut.allCases.count)
        XCTAssertTrue(DockFocusShortcut.allCases.allSatisfy { $0.carbonModifiers != 0 })
    }

    func testSettingsWithoutShortcutUseDefault() throws {
        let data = Data(#"{"mode":"both","position":"bottom","iconSize":52,"autoHide":false,"showRunningApps":false}"#.utf8)
        let settings = try JSONDecoder().decode(DockSettings.self, from: data)

        XCTAssertEqual(settings.dockFocusShortcut, .controlOptionCommandD)
    }

    func testSelectedShortcutPersistsInSettings() throws {
        var settings = DockSettings()
        settings.dockFocusShortcut = .controlOptionCommandK

        let decoded = try JSONDecoder().decode(DockSettings.self, from: JSONEncoder().encode(settings))

        XCTAssertEqual(decoded, settings)
    }
}
