import AppKit
import XCTest
@testable import DockStudio

final class PanelFrameGeometryTests: XCTestCase {
    func testVisibleDockFrameFitsWithinScreenAtEveryPositionAndSize() {
        let screens = [
            NSRect(x: 0, y: 0, width: 1000, height: 1000),
            NSRect(x: 0, y: 0, width: 1440, height: 900),
            NSRect(x: -1920, y: 120, width: 2560, height: 1440)
        ]

        for screen in screens {
            let available = screen.insetBy(dx: 10, dy: 10)
            for position in [DockPosition.bottom, .left, .right] {
                let size = position == .bottom
                    ? NSSize(width: 318, height: 157)
                    : NSSize(width: 89, height: 440)
                let origin = DockInteractionGeometry.panelOrigin(
                    screen: screen,
                    available: available,
                    size: size,
                    position: position
                )
                let visibleFrame = NSRect(origin: origin, size: size)
                    .insetBy(dx: DockInteractionGeometry.panelPadding, dy: DockInteractionGeometry.panelPadding)

                XCTAssertGreaterThanOrEqual(visibleFrame.minX, screen.minX)
                XCTAssertLessThanOrEqual(visibleFrame.maxX, screen.maxX)
                XCTAssertGreaterThanOrEqual(visibleFrame.minY, screen.minY)
                XCTAssertLessThanOrEqual(visibleFrame.maxY, screen.maxY)
            }
        }
    }

    func testBottomPanelPaddingKeepsVisibleEdgeFivePointsFromScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1000, height: 1000)
        let origin = DockInteractionGeometry.panelOrigin(
            screen: screen,
            available: screen.insetBy(dx: 10, dy: 10),
            size: NSSize(width: 318, height: 157),
            position: .bottom
        )

        XCTAssertEqual(origin.y + DockInteractionGeometry.bottomGap,
                       screen.minY + DockInteractionGeometry.bottomGap)
        XCTAssertEqual(origin.y, screen.minY)
    }

    func testMaximumIconSizePanelFitsWithinScreenHeight() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = DockSettings.iconSizeRange.upperBound
        let panelSize = DockPanelSizing.size(
            position: .bottom,
            dockLength: 420,
            dockThickness: CGFloat(size) + 65,
            panelPadding: DockInteractionGeometry.panelPadding * 2,
            sideLabelGutter: 0,
            maximumLength: screen.width
        )
        let origin = DockInteractionGeometry.panelOrigin(
            screen: screen,
            available: screen.insetBy(dx: 10, dy: 10),
            size: panelSize,
            position: .bottom
        )
        let panelFrame = NSRect(origin: origin, size: panelSize)

        XCTAssertLessThanOrEqual(panelSize.height + origin.y - screen.minY, screen.height)
        XCTAssertGreaterThanOrEqual(panelFrame.minY, screen.minY)
        XCTAssertLessThanOrEqual(panelFrame.maxY, screen.maxY)
        XCTAssertEqual(panelSize.height, CGFloat(size) + 65 + DockInteractionGeometry.panelPadding
                       + DockInteractionGeometry.bottomGap)
    }

    func testTrashFitsPanelWithAndWithoutAccessibilityNoticeAcrossDockSizes() {
        let panelPadding: CGFloat = 16
        let cases: [(iconSize: CGFloat, itemCount: Int)] = [
            (32, 1), (32, 8), (52, 2), (52, 12), (64, 2), (64, 10), (96, 1), (96, 6)
        ]

        for item in cases {
            let dockLength = max(220, 24 + CGFloat(item.itemCount) * (10 + item.iconSize)
                + 21 + 10 + item.iconSize)
            for hasNotice in [false, true] {
                let size = DockPanelSizing.size(
                    position: .bottom,
                    dockLength: dockLength,
                    dockThickness: item.iconSize + 65,
                    panelPadding: panelPadding,
                    sideLabelGutter: 0,
                    maximumLength: 1400,
                    accessibilityNoticeHeight: hasNotice ? DockPanelSizing.accessibilityNoticeHeight : 0,
                    accessibilityNoticeSpacing: hasNotice ? DockPanelSizing.accessibilityNoticeSpacing : 0,
                    accessibilityNoticeWidth: hasNotice ? DockPanelSizing.accessibilityNoticeWidth : 0
                )
                let trashMaxX = panelPadding + dockLength

                XCTAssertLessThanOrEqual(trashMaxX, size.width,
                                         "icon size \(item.iconSize), items \(item.itemCount), notice \(hasNotice)")
            }
        }
    }

    func testAccessibilityNoticeWidthExpandsPanelWhenDockRowIsShorter() {
        let size = DockPanelSizing.size(
            position: .bottom,
            dockLength: 240,
            dockThickness: 117,
            panelPadding: 16,
            sideLabelGutter: 0,
            maximumLength: 1400,
            accessibilityNoticeHeight: DockPanelSizing.accessibilityNoticeHeight,
            accessibilityNoticeSpacing: DockPanelSizing.accessibilityNoticeSpacing,
            accessibilityNoticeWidth: DockPanelSizing.accessibilityNoticeWidth
        )

        XCTAssertEqual(size.width, DockPanelSizing.accessibilityNoticeWidth + 16)
        XCTAssertEqual(size.height, 117 + 8 + DockInteractionGeometry.bottomGap
                       + DockPanelSizing.accessibilityNoticeHeight
                       + DockPanelSizing.accessibilityNoticeSpacing)
    }

    func testAccessibilityNoticeAppearsOnlyWithoutPermissionAndWithAnApplication() {
        let app = DockItem(name: "Safari", kind: .application, target: nil)
        let folder = DockItem(name: "Downloads", kind: .folder, target: nil)

        XCTAssertTrue(DockPanelSizing.hasAccessibilityNotice(permissionGranted: false, items: [app, folder]))
        XCTAssertFalse(DockPanelSizing.hasAccessibilityNotice(permissionGranted: true, items: [app]))
        XCTAssertFalse(DockPanelSizing.hasAccessibilityNotice(permissionGranted: false, items: [folder]))
    }
}
