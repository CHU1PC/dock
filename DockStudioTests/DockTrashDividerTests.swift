import XCTest
@testable import DockStudio

final class DockTrashDividerTests: XCTestCase {
    private func item(_ name: String, _ kind: DockItemKind) -> DockItem {
        DockItem(name: name, kind: kind, target: kind == .spacer ? nil : "file:///\(name)")
    }

    func testTrailingSpacerDrawsNoLineNextToResizeHandle() {
        let items = [item("App", .application), item("Spacer", .spacer)]
        XCTAssertFalse(DockTrashDivider.spacerDrawsLine(index: 1, itemCount: 2))
        XCTAssertEqual(DockTrashDivider.linesDirectlyBeforeTrash(items: items, dividerBefore: []), 1)
    }

    func testSpacerInTheMiddleKeepsItsLine() {
        XCTAssertTrue(DockTrashDivider.spacerDrawsLine(index: 1, itemCount: 3))
    }

    func testDefaultItemsWithoutDocumentsHaveOneLine() {
        let layout = DockSectionLayout.arrange(
            pinned: [item("Finder", .application), item("Spacer", .spacer)],
            running: [], recent: [], arrangement: .standardSections)
        XCTAssertEqual(DockTrashDivider.linesDirectlyBeforeTrash(items: layout.items, dividerBefore: layout.dividerBefore), 1)
    }

    func testDocumentsAfterSpacerKeepSectionDividerAndOneLineBeforeTrash() {
        let layout = DockSectionLayout.arrange(
            pinned: [item("Finder", .application), item("Spacer", .spacer), item("Downloads", .folder)],
            running: [], recent: [], arrangement: .standardSections)
        XCTAssertEqual(layout.dividerBefore, [2])
        XCTAssertEqual(DockTrashDivider.linesDirectlyBeforeTrash(items: layout.items, dividerBefore: layout.dividerBefore), 1)
    }

    func testDividerAtEndOfItemsCountsWithResizeHandle() {
        let items = [item("App", .application)]
        XCTAssertEqual(DockTrashDivider.linesDirectlyBeforeTrash(items: items, dividerBefore: [1]), 2)
    }

    func testEmptyItemsHaveOnlyResizeHandleLine() {
        XCTAssertEqual(DockTrashDivider.linesDirectlyBeforeTrash(items: [], dividerBefore: []), 1)
    }
}
