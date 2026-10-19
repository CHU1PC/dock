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

        XCTAssertEqual(origin.y + DockInteractionGeometry.panelPadding,
                       screen.minY + DockInteractionGeometry.bottomGap)
        XCTAssertEqual(origin.y, screen.minY + DockInteractionGeometry.bottomGap
                       - DockInteractionGeometry.panelPadding)
    }

    func testAccessibilityNoticeAddsPanelHeightWithoutReducingDockRowLength() {
        let withNotice = DockPanelSizing.size(
            position: .bottom,
            dockLength: 420,
            dockThickness: 117,
            panelPadding: 16,
            sideLabelGutter: 0,
            maximumLength: 1400,
            accessibilityNoticeHeight: DockPanelSizing.accessibilityNoticeHeight,
            accessibilityNoticeSpacing: DockPanelSizing.accessibilityNoticeSpacing
        )
        let withoutNotice = DockPanelSizing.size(
            position: .bottom,
            dockLength: 420,
            dockThickness: 117,
            panelPadding: 16,
            sideLabelGutter: 0,
            maximumLength: 1400
        )

        XCTAssertEqual(withNotice.width, withoutNotice.width)
        XCTAssertEqual(withNotice.height - withoutNotice.height,
                       DockPanelSizing.accessibilityNoticeHeight + DockPanelSizing.accessibilityNoticeSpacing)
    }

    func testAccessibilityNoticeAppearsOnlyWithoutPermissionAndWithAnApplication() {
        let app = DockItem(name: "Safari", kind: .application, target: nil)
        let folder = DockItem(name: "Downloads", kind: .folder, target: nil)

        XCTAssertTrue(DockPanelSizing.hasAccessibilityNotice(permissionGranted: false, items: [app, folder]))
        XCTAssertFalse(DockPanelSizing.hasAccessibilityNotice(permissionGranted: true, items: [app]))
        XCTAssertFalse(DockPanelSizing.hasAccessibilityNotice(permissionGranted: false, items: [folder]))
    }
}
