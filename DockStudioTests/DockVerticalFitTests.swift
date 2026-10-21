import XCTest
@testable import DockStudio

final class DockVerticalFitTests: XCTestCase {
    private func content(items: Int, magnification: Bool = true) -> DockVerticalFit.Content {
        DockVerticalFit.Content(fixedLength: 24, iconItemCount: items, minimizedSlots: 0,
                                magnificationReserve: magnification ? 1.35 : 0)
    }

    func testSidePreviewContentFitsFrameWhenMinimumSizeCanFit() {
        for position in [DockPosition.left, .right] {
            for items in [2, 6, 12] {
                for icon in [32.0, 52, 64, 96] {
                    for notice in [false, true] {
                        for windowHeight in [700.0, 900.0] {
                            let extent = DockPreviewLayout.noticeExtent(hasNotice: notice)
                            let available = Double(max(0, windowHeight - 188 - extent))
                            let c = content(items: items)
                            let size = DockVerticalFit.iconSize(c, maximumSize: icon, minimumSize: 16,
                                                                availableLength: available)
                            let length = DockVerticalFit.contentLength(c, iconSize: size, maximumSize: icon)
                            let frame = DockPreviewLayout.frameSize(
                                containerSize: CGSize(width: 1080, height: windowHeight), position: position,
                                length: CGFloat(max(220, length)), thickness: 200, noticeExtent: extent)
                            let label = "\(position) items=\(items) icon=\(icon) notice=\(notice) h=\(windowHeight)"
                            XCTAssertGreaterThanOrEqual(size, 16, label)
                            XCTAssertLessThanOrEqual(size, icon, label)
                            let minimumLength = DockVerticalFit.contentLength(c, iconSize: 16, maximumSize: icon)
                            if minimumLength <= available {
                                XCTAssertLessThanOrEqual(max(220, length), Double(frame.height) - extent + 0.001, label)
                                let unshrunk = DockVerticalFit.contentLength(c, iconSize: icon, maximumSize: icon)
                                if unshrunk > available { XCTAssertLessThan(size, icon, label) }
                            } else {
                                XCTAssertEqual(size, 16, label)
                            }
                        }
                    }
                }
            }
        }
    }

    func testSixItemsAtLargestIconShrinkInShortWindow() {
        let c = content(items: 6)
        let size = DockVerticalFit.iconSize(c, maximumSize: 96, minimumSize: 16, availableLength: 700 - 188 - 70)
        XCTAssertLessThan(size, 96)
        XCTAssertGreaterThan(size, 16)
    }

    func testIconSizeIsUnchangedWhenContentAlreadyFits() {
        let c = content(items: 2, magnification: false)
        XCTAssertEqual(DockVerticalFit.iconSize(c, maximumSize: 32, minimumSize: 16, availableLength: 1000), 32)
    }

    func testTooManyItemsKeepMinimumSizeAndOverflowForScrolling() {
        let c = content(items: 40)
        let size = DockVerticalFit.iconSize(c, maximumSize: 64, minimumSize: 16, availableLength: 300)
        XCTAssertEqual(size, 16)
        XCTAssertGreaterThan(DockVerticalFit.contentLength(c, iconSize: size, maximumSize: 64), 300)
    }

    @MainActor
    func testFitMatchesMeasuredLayoutLength() {
        let store = DockStore.preview()
        var settings = store.document.settings
        settings.iconSize = 64
        settings.position = .left
        XCTAssertTrue(store.updateSettings(settings))
        let maximum = store.effectiveIconSize
        let c = DockMetrics.verticalFitContent(for: store)
        for size in [16.0, 40, 64] {
            XCTAssertEqual(DockVerticalFit.contentLength(c, iconSize: size, maximumSize: maximum),
                           Double(DockMetrics.length(for: store, iconSize: size)), accuracy: 0.5)
        }
    }

    @MainActor
    func testVerticalFitShrinksOnAnyBackgroundOnlyWhenForced() {
        let store = DockStore.preview()
        var settings = store.document.settings
        settings.iconSize = 96
        settings.position = .left
        XCTAssertTrue(store.updateSettings(settings))
        let available: CGFloat = 250
        XCTAssertEqual(DockMetrics.effectiveIconSize(for: store, availableLength: available), 96)
        XCTAssertLessThan(DockMetrics.effectiveIconSize(for: store, availableLength: available, forceFit: true), 96)
    }
}
