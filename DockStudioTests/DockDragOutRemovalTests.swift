import XCTest
@testable import DockStudio

final class DockDragOutRemovalTests: XCTestCase {
    private let bar = CGSize(width: 400, height: 80)

    func testInsideBarIsNotOutside() {
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: 40), barSize: bar))
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 0, y: 0), barSize: bar))
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 400, y: 80), barSize: bar))
    }

    func testWithinMarginIsNotOutside() {
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: -DockDragOutRemoval.margin), barSize: bar))
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 400 + DockDragOutRemoval.margin - 1, y: 40), barSize: bar))
    }

    func testBeyondMarginIsOutsideOnEverySide() {
        XCTAssertTrue(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: -60), barSize: bar))
        XCTAssertTrue(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: 200), barSize: bar))
        XCTAssertTrue(DockDragOutRemoval.isOutside(location: CGPoint(x: -60, y: 40), barSize: bar))
        XCTAssertTrue(DockDragOutRemoval.isOutside(location: CGPoint(x: 600, y: 40), barSize: bar))
    }

    func testUnmeasuredBarNeverRemoves() {
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 900, y: 900), barSize: .zero))
    }
}
