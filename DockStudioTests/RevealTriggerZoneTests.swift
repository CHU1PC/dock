import XCTest
@testable import DockStudio

final class RevealTriggerZoneTests: XCTestCase {
    private let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
    private let thickness = DockInteractionGeometry.revealZoneThickness

    private func zone(_ position: DockPosition, screen: NSRect? = nil, panel: NSRect) -> NSRect {
        DockInteractionGeometry.reveal(screen: screen ?? self.screen, panel: panel, position: position)
    }

    func testThicknessIsThinBand() {
        XCTAssertGreaterThanOrEqual(thickness, 1)
        XCTAssertLessThanOrEqual(thickness, 2)
    }

    func testBottomZoneIsAtScreenEdge() {
        let panel = NSRect(x: 500, y: 0, width: 400, height: 90)
        let z = zone(.bottom, panel: panel)
        XCTAssertEqual(z, NSRect(x: 500, y: 0, width: 400, height: thickness))
        XCTAssertTrue(z.contains(NSPoint(x: 600, y: 0)))
        XCTAssertTrue(z.contains(NSPoint(x: 600, y: thickness - 0.5)))
        XCTAssertFalse(z.contains(NSPoint(x: 600, y: thickness)))
        XCTAssertFalse(z.contains(NSPoint(x: 600, y: thickness + 1)))
    }

    func testLeftZoneIsAtScreenEdge() {
        let panel = NSRect(x: 10, y: 300, width: 80, height: 300)
        let z = zone(.left, panel: panel)
        XCTAssertEqual(z, NSRect(x: 0, y: 300, width: thickness, height: 300))
        XCTAssertTrue(z.contains(NSPoint(x: 0, y: 400)))
        XCTAssertFalse(z.contains(NSPoint(x: thickness + 1, y: 400)))
    }

    func testRightZoneIsAtScreenEdge() {
        let panel = NSRect(x: 1350, y: 300, width: 80, height: 300)
        let z = zone(.right, panel: panel)
        XCTAssertEqual(z, NSRect(x: 1440 - thickness, y: 300, width: thickness, height: 300))
        XCTAssertTrue(z.contains(NSPoint(x: 1440 - 0.5, y: 400)))
        XCTAssertFalse(z.contains(NSPoint(x: 1440 - thickness - 1, y: 400)))
    }

    func testZoneFollowsScreenFrameOnSecondaryDisplays() {
        let right = NSRect(x: 1440, y: -200, width: 1920, height: 1080)
        let below = NSRect(x: 0, y: -1080, width: 1440, height: 1080)
        let bottomPanel = NSRect(x: 1900, y: -200, width: 400, height: 90)
        XCTAssertEqual(zone(.bottom, screen: right, panel: bottomPanel).minY, -200)
        XCTAssertEqual(zone(.left, screen: right, panel: NSRect(x: 1450, y: 0, width: 80, height: 300)).minX, 1440)
        XCTAssertEqual(zone(.right, screen: right, panel: NSRect(x: 3280, y: 0, width: 80, height: 300)).maxX, 3360)
        XCTAssertEqual(zone(.bottom, screen: below, panel: NSRect(x: 500, y: -1080, width: 400, height: 90)).minY, -1080)
        XCTAssertFalse(zone(.bottom, screen: below, panel: NSRect(x: 500, y: -1080, width: 400, height: 90))
            .contains(NSPoint(x: 600, y: 0)))
    }

    func testKeepVisibleCoversGapToScreenEdge() {
        let interaction = NSRect(x: 508, y: 8, width: 384, height: 84)
        let bottom = DockInteractionGeometry.keepVisible(interaction: interaction, screen: screen, position: .bottom)
        XCTAssertTrue(bottom.contains(NSPoint(x: 600, y: 0)))
        XCTAssertTrue(bottom.contains(NSPoint(x: 600, y: 5)))
        XCTAssertTrue(bottom.contains(NSPoint(x: 600, y: 50)))
        XCTAssertFalse(bottom.contains(NSPoint(x: 600, y: 92)))

        let leftInteraction = NSRect(x: 18, y: 308, width: 64, height: 284)
        let left = DockInteractionGeometry.keepVisible(interaction: leftInteraction, screen: screen, position: .left)
        XCTAssertTrue(left.contains(NSPoint(x: 0, y: 400)))
        XCTAssertTrue(left.contains(NSPoint(x: 40, y: 400)))

        let rightInteraction = NSRect(x: 1358, y: 308, width: 64, height: 284)
        let right = DockInteractionGeometry.keepVisible(interaction: rightInteraction, screen: screen, position: .right)
        XCTAssertTrue(right.contains(NSPoint(x: 1439.5, y: 400)))
        XCTAssertTrue(right.contains(NSPoint(x: 1400, y: 400)))
    }
}
