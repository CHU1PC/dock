import XCTest
@testable import DockStudio

final class NotificationBadgeReaderTests: XCTestCase {
    func testBadgeUsesCanonicalApplicationURLPath() {
        let app = DockItem(name: "Mail", kind: .application,
                           target: URL(fileURLWithPath: "/Applications/Mail.app").absoluteString)
        let badges = ["/Applications/Mail.app": "42"]

        XCTAssertEqual(NotificationBadgeSnapshot.badge(for: app, in: badges), "42")
    }

    func testBadgeIsNotAppliedToNonApplicationItems() {
        let folder = DockItem(name: "Mail", kind: .folder,
                              target: URL(fileURLWithPath: "/Applications/Mail.app").absoluteString)

        XCTAssertNil(NotificationBadgeSnapshot.badge(for: folder, in: ["/Applications/Mail.app": "42"]))
    }

    func testBadgeIsAbsentWhenDockHasNoStatusLabel() {
        let app = DockItem(name: "Mail", kind: .application,
                           target: URL(fileURLWithPath: "/Applications/Mail.app").absoluteString)

        XCTAssertNil(NotificationBadgeSnapshot.badge(for: app, in: [:]))
    }
}
