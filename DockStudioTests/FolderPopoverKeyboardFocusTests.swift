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
}
