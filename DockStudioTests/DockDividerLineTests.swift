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

    func testBottomLineSpansSameRangeAsIconAboveIndicatorRow() {
        for size in [16.0, 52.0, 128.0] {
            let line = DockDividerLine.size(iconSize: size, vertical: false)
            let insets = DockDividerLine.insets(vertical: false)
            let cellHeight = CGFloat(size) + DockDividerLine.indicatorRowHeight
            XCTAssertEqual(insets.top + line.height + insets.bottom, cellHeight)
            XCTAssertEqual(insets.bottom, DockDividerLine.indicatorRowHeight)
            XCTAssertEqual(insets.top, 0)
        }
    }

    func testSideLineIsCenteredOnIconColumnWithoutCrossAxisInsets() {
        for size in [16.0, 52.0, 128.0] {
            let line = DockDividerLine.size(iconSize: size, vertical: true)
            let insets = DockDividerLine.insets(vertical: true)
            XCTAssertEqual(insets.leading + line.width + insets.trailing, CGFloat(size))
            XCTAssertEqual(insets.top, DockDividerLine.axisPadding)
            XCTAssertEqual(insets.bottom, DockDividerLine.axisPadding)
        }
    }

    func testAxisPaddingMatchesPreviousSpacing() {
        let bottom = DockDividerLine.insets(vertical: false)
        XCTAssertEqual(bottom.leading + bottom.trailing, 10)
    }
}
