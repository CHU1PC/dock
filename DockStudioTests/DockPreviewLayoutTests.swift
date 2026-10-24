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

    func testNoticeExtentIsZeroWithoutNoticeAndPanelRowHeightWithNotice() {
        XCTAssertEqual(DockPreviewLayout.noticeExtent(hasNotice: false), 0)
        XCTAssertEqual(DockPreviewLayout.noticeExtent(hasNotice: true),
                       DockPanelSizing.accessibilityNoticeHeight + DockPanelSizing.accessibilityNoticeSpacing)
    }

    func testNoticeRowKeepsItemRowSizeInEveryPosition() {
        let extent = DockPreviewLayout.noticeExtent(hasNotice: true)
        let container = CGSize(width: 2000, height: 2000)
        for position in [DockPosition.bottom, .left, .right] {
            let plain = DockPreviewLayout.frameSize(containerSize: container, position: position,
                                                    length: 500, thickness: 120)
            let noticed = DockPreviewLayout.frameSize(containerSize: container, position: position,
                                                      length: 500, thickness: 120, noticeExtent: extent)
            XCTAssertEqual(noticed.width, plain.width, "\(position)")
            XCTAssertEqual(noticed.height, plain.height + extent, "\(position)")
        }
    }

    func testNoticeExtentIsClampedToAvailableHeight() {
        let size = DockPreviewLayout.frameSize(
            containerSize: CGSize(width: 940, height: 650),
            position: .left,
            length: 1800,
            thickness: 321,
            noticeExtent: DockPreviewLayout.noticeExtent(hasNotice: true)
        )
        XCTAssertEqual(size.height, 462)
    }

    @MainActor
    func testVerticalLengthCoversIconItemsAndTrashAtMeasuredPitch() {
        let store = DockStore.preview()
        var settings = store.document.settings
        settings.iconSize = 76
        settings.position = .bottom
        XCTAssertTrue(store.updateSettings(settings))
        let horizontal = DockMetrics.length(for: store)
        settings.position = .left
        XCTAssertTrue(store.updateSettings(settings))
        XCTAssertGreaterThan(horizontal, 220)
        XCTAssertEqual(DockMetrics.length(for: store),
                       horizontal + CGFloat(DockMetrics.verticalSeparatorLength - 21),
                       accuracy: 0.5)
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
