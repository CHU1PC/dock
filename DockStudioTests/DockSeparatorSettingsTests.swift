import XCTest
@testable import DockStudio

final class DockSeparatorSettingsTests: XCTestCase {
    func testChangingPositionPreservesOtherDockSettings() {
        var original = DockSettings()
        original.autoHide = true
        original.iconSize = 68

        let updated = DockSeparatorSettings.position(.left, in: original)

        XCTAssertEqual(updated.position, .left)
        XCTAssertTrue(updated.autoHide)
        XCTAssertEqual(updated.iconSize, 68)
        XCTAssertEqual(original.position, .bottom)
    }

    func testAutoHideAndMagnificationToggleOnlyTheirOwnValues() {
        var settings = DockSettings()
        settings.position = .right
        var appearance = DockAppearance()
        let magnification = appearance.magnification

        let updatedSettings = DockSeparatorSettings.toggledAutoHide(in: settings)
        appearance = DockSeparatorSettings.toggledMagnification(in: appearance)

        XCTAssertTrue(updatedSettings.autoHide)
        XCTAssertEqual(updatedSettings.position, .right)
        XCTAssertNotEqual(appearance.magnification, magnification)
    }
}
