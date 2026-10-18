import XCTest
@testable import DockStudio

final class DockPreviewLayoutTests: XCTestCase {
    func testBottomPreviewFitsAvailableWidthAndReservesControlSpace() {
        let size = DockPreviewLayout.frameSize(
            containerSize: CGSize(width: 940, height: 650),
            position: .bottom,
            length: 1800,
            thickness: 321
        )

        XCTAssertEqual(size, CGSize(width: 890, height: 321))
    }

    func testSidePreviewFitsAvailableHeightAndUsesFixedBarWidth() {
        for position in [DockPosition.left, .right] {
            let size = DockPreviewLayout.frameSize(
                containerSize: CGSize(width: 940, height: 650),
                position: position,
                length: 1800,
                thickness: 321
            )

            XCTAssertEqual(size, CGSize(width: 190, height: 462))
        }
    }

    func testSmallContainerClampsPreviewToAvailableSpace() {
        let size = DockPreviewLayout.frameSize(
            containerSize: CGSize(width: 40, height: 100),
            position: .right,
            length: 1800,
            thickness: 321
        )

        XCTAssertEqual(size, .zero)
    }
}
