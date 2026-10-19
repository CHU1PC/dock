import XCTest
@testable import DockStudio

final class FolderPopoverKeyboardFocusTests: XCTestCase {
    func testInitialGridFocusSelectsFirstItemOnlyForGridMode() {
        let first = DockItem(name: "First", kind: .file, target: "file:///tmp/first")
        let second = DockItem(name: "Second", kind: .file, target: "file:///tmp/second")

        XCTAssertEqual(FolderPopoverKeyboardFocus.initialGridItemID(mode: .grid, items: [first, second]), first.id)
        XCTAssertNil(FolderPopoverKeyboardFocus.initialGridItemID(mode: .list, items: [first, second]))
        XCTAssertNil(FolderPopoverKeyboardFocus.initialGridItemID(mode: .grid, items: []))
    }

    func testOpenPopoverRoutesEscapeAndArrowKeys() {
        XCTAssertEqual(FolderPopoverKeyboardFocus.keyRoute(keyCode: 53, isPopoverOpen: true), .dismiss)
        XCTAssertEqual(FolderPopoverKeyboardFocus.keyRoute(keyCode: 123, isPopoverOpen: true), .left)
        XCTAssertEqual(FolderPopoverKeyboardFocus.keyRoute(keyCode: 124, isPopoverOpen: true), .right)
        XCTAssertEqual(FolderPopoverKeyboardFocus.keyRoute(keyCode: 125, isPopoverOpen: true), .down)
        XCTAssertEqual(FolderPopoverKeyboardFocus.keyRoute(keyCode: 126, isPopoverOpen: true), .up)
    }

    func testClosedPopoverDoesNotRouteKeys() {
        XCTAssertNil(FolderPopoverKeyboardFocus.keyRoute(keyCode: 53, isPopoverOpen: false))
        XCTAssertNil(FolderPopoverKeyboardFocus.keyRoute(keyCode: 124, isPopoverOpen: false))
        XCTAssertNil(FolderPopoverKeyboardFocus.keyRoute(keyCode: 0, isPopoverOpen: true))
    }
}
