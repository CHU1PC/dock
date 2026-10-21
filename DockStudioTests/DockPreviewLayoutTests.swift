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

    func testBottomPreviewReservesInlineNoticeSoTrashStaysInsideFrame() {
        XCTAssertEqual(DockPreviewLayout.length(dockLength: 500, hasInlineNotice: true, vertical: false),
                       500 + DockPreviewLayout.inlineNoticeLength)
        XCTAssertEqual(DockPreviewLayout.length(dockLength: 500, hasInlineNotice: false, vertical: false), 500)
        XCTAssertEqual(DockPreviewLayout.length(dockLength: 500, hasInlineNotice: true, vertical: true), 500)

        let size = DockPreviewLayout.frameSize(
            containerSize: CGSize(width: 1400, height: 650),
            position: .bottom,
            length: DockPreviewLayout.length(dockLength: 500, hasInlineNotice: true, vertical: false),
            thickness: 120
        )
        XCTAssertEqual(size.width, 500 + DockPreviewLayout.inlineNoticeLength)
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
