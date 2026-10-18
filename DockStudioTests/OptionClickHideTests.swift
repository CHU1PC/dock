import XCTest
@testable import DockStudio

final class OptionClickHideTests: XCTestCase {
    private func action(_ flags: NSEvent.ModifierFlags, target: String? = "a", front: String? = "a", running: Bool = true) -> OptionClickAction {
        OptionClickPolicy.action(flags: flags, targetBundleIdentifier: target, frontmostBundleIdentifier: front, targetIsRunning: running)
    }

    func testOptionClickOnFrontmostRunningAppHides() {
        XCTAssertEqual(action(.option), .hideFrontmost)
        XCTAssertEqual(action([.option, .capsLock]), .hideFrontmost)
    }

    func testPlainClickLaunches() {
        XCTAssertEqual(action([]), .launch)
        XCTAssertEqual(action(.capsLock), .launch)
    }

    func testOptionClickOnNonFrontmostAppLaunches() {
        XCTAssertEqual(action(.option, front: "b"), .launch)
        XCTAssertEqual(action(.option, front: nil), .launch)
    }

    func testTerminatedTargetNeverHidesAnotherApp() {
        XCTAssertEqual(action(.option, running: false), .launch)
        XCTAssertEqual(action(.option, target: nil), .launch)
    }

    func testOtherModifierCombinationsLaunch() {
        for flags: NSEvent.ModifierFlags in [[.option, .command], [.option, .shift], [.option, .control]] {
            XCTAssertEqual(action(flags), .launch)
        }
    }
}
