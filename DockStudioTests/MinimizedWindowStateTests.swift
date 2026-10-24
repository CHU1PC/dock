import XCTest
@testable import DockStudio

final class MinimizedWindowStateTests: XCTestCase {
    private func window(_ id: String, title: String = "Doc") -> MinimizedWindow {
        MinimizedWindow(id: id, applicationIdentifier: "bundle:a", title: title, applicationName: "A", applicationIcon: nil)
    }

    func testEquivalentStatesAreDetected() {
        XCTAssertTrue(MinimizedWindowState.notChecked.isEquivalent(to: .notChecked))
        XCTAssertTrue(MinimizedWindowState.permissionDenied.isEquivalent(to: .permissionDenied))
        XCTAssertTrue(MinimizedWindowState.available([]).isEquivalent(to: .available([])))
        XCTAssertTrue(MinimizedWindowState.available([window("1")]).isEquivalent(to: .available([window("1")])))
    }

    func testDifferentStatesAreNotEquivalent() {
        XCTAssertFalse(MinimizedWindowState.notChecked.isEquivalent(to: .permissionDenied))
        XCTAssertFalse(MinimizedWindowState.available([]).isEquivalent(to: .permissionDenied))
        XCTAssertFalse(MinimizedWindowState.available([window("1")]).isEquivalent(to: .available([window("2")])))
        XCTAssertFalse(MinimizedWindowState.available([window("1")]).isEquivalent(to: .available([window("1", title: "Other")])))
        XCTAssertFalse(MinimizedWindowState.available([window("1")]).isEquivalent(to: .available([])))
    }
}
