import XCTest
@testable import DockStudio

final class DockIconSizeResizeTests: XCTestCase {
    func testDragTowardScreenInteriorIncreasesIconSizeForEveryDockPosition() {
        XCTAssertEqual(DockIconSizeResize.size(initialSize: 52, dragTranslation: CGSize(width: 0, height: -20), position: .bottom), 72)
        XCTAssertEqual(DockIconSizeResize.size(initialSize: 52, dragTranslation: CGSize(width: 20, height: 0), position: .left), 72)
        XCTAssertEqual(DockIconSizeResize.size(initialSize: 52, dragTranslation: CGSize(width: -20, height: 0), position: .right), 72)
    }

    func testDragTowardScreenEdgeDecreasesIconSize() {
        XCTAssertEqual(DockIconSizeResize.size(initialSize: 52, dragTranslation: CGSize(width: 0, height: 20), position: .bottom), 32)
        XCTAssertEqual(DockIconSizeResize.size(initialSize: 52, dragTranslation: CGSize(width: -20, height: 0), position: .left), 32)
        XCTAssertEqual(DockIconSizeResize.size(initialSize: 52, dragTranslation: CGSize(width: 20, height: 0), position: .right), 32)
    }

    func testResizeClampsToIconSizeRange() {
        XCTAssertEqual(DockIconSizeResize.size(initialSize: 120, dragTranslation: CGSize(width: 0, height: -40), position: .bottom), DockSettings.iconSizeRange.upperBound)
        XCTAssertEqual(DockIconSizeResize.size(initialSize: 24, dragTranslation: CGSize(width: 0, height: 40), position: .bottom), DockSettings.iconSizeRange.lowerBound)
    }

    func testResizeUsesOnlyTheAxisPerpendicularToTheSeparator() {
        XCTAssertEqual(DockIconSizeResize.size(initialSize: 52, dragTranslation: CGSize(width: 30, height: 0), position: .bottom), 52)
        XCTAssertEqual(DockIconSizeResize.size(initialSize: 52, dragTranslation: CGSize(width: 0, height: -30), position: .left), 52)
    }

    func testNonFiniteTranslationLeavesSizeUnchanged() {
        XCTAssertEqual(DockIconSizeResize.size(initialSize: 52, dragTranslation: CGSize(width: Double.nan, height: Double.infinity), position: .bottom), 52)
    }
}
