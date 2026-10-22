import XCTest
@testable import DockStudio

final class DockDividerLineTests: XCTestCase {
    func testLengthFollowsIconSize() {
        XCTAssertEqual(DockDividerLine.length(iconSize: 16), 16)
        XCTAssertEqual(DockDividerLine.length(iconSize: 52), 52)
        XCTAssertEqual(DockDividerLine.length(iconSize: 128), 128)
    }

    func testBottomLineIsVerticalAndSideLineIsHorizontal() {
        XCTAssertEqual(DockDividerLine.size(iconSize: 52, vertical: false), CGSize(width: 1, height: 52))
        XCTAssertEqual(DockDividerLine.size(iconSize: 52, vertical: true), CGSize(width: 52, height: 1))
    }

    func testLengthStaysWithinIconSizeAcrossRange() {
        for size in stride(from: DockSettings.iconSizeRange.lowerBound, through: DockSettings.iconSizeRange.upperBound, by: 4) {
            XCTAssertLessThanOrEqual(DockDividerLine.length(iconSize: size), CGFloat(size))
        }
    }

    func testInvalidIconSizeFallsBackToMinimumLength() {
        XCTAssertEqual(DockDividerLine.length(iconSize: .nan), 1)
        XCTAssertEqual(DockDividerLine.length(iconSize: 0), 1)
    }
}
