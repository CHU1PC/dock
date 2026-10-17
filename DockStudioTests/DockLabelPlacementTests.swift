import XCTest
@testable import DockStudio

final class DockLabelPlacementTests: XCTestCase {
    private let bounds = CGSize(width: 120, height: 600)

    func testLeftLabelSitsInsideRightOfBarAndFollowsItem() {
        let center = DockLabelPlacement.center(position: .left, itemFrame: CGRect(x: 10, y: 200, width: 60, height: 60),
                                               bounds: bounds, width: 100)
        XCTAssertEqual(center.x - 50, bounds.width + DockLabelPlacement.gap)
        XCTAssertEqual(center.y, 230)
    }

    func testRightLabelSitsInsideLeftOfBar() {
        let center = DockLabelPlacement.center(position: .right, itemFrame: CGRect(x: 10, y: 200, width: 60, height: 60),
                                               bounds: bounds, width: 100)
        XCTAssertEqual(center.x + 50, -DockLabelPlacement.gap)
    }

    func testSideLabelStaysWithinBarHeight() {
        for position in [DockPosition.left, .right] {
            let top = DockLabelPlacement.center(position: position, itemFrame: CGRect(x: 0, y: -40, width: 60, height: 60),
                                                bounds: bounds, width: 100)
            let bottom = DockLabelPlacement.center(position: position, itemFrame: CGRect(x: 0, y: 590, width: 60, height: 60),
                                                   bounds: bounds, width: 100)
            XCTAssertEqual(top.y, 16)
            XCTAssertEqual(bottom.y, bounds.height - 16)
        }
    }

    func testLongNamesAreCappedAndSideLabelFitsGutter() {
        XCTAssertEqual(DockLabelPlacement.width(measured: 900, available: DockLabelPlacement.maxWidth), DockLabelPlacement.maxWidth)
        XCTAssertEqual(DockLabelPlacement.width(measured: 5, available: 500), 40)
        XCTAssertLessThanOrEqual(DockLabelPlacement.gap + DockLabelPlacement.maxWidth, DockMetrics.sideLabelGutter)
    }

    func testBottomLabelKeepsAboveItemAndInsideBar() {
        let wide = CGSize(width: 400, height: 90)
        let edge = DockLabelPlacement.center(position: .bottom, itemFrame: CGRect(x: 0, y: 40, width: 50, height: 50),
                                             bounds: wide, width: 120)
        XCTAssertEqual(edge.x, 60 + DockLabelPlacement.gap)
        XCTAssertEqual(edge.y, 22)
    }
}
