import XCTest
@testable import DockStudio

final class OptionClickHideTests: XCTestCase {
    private func action(_ flags: NSEvent.ModifierFlags, target: String? = "a", front: String? = "a",
                        own: String? = "own", running: Bool = true) -> OptionClickAction {
        OptionClickPolicy.action(flags: flags, targetBundleIdentifier: target, frontmostBundleIdentifier: front,
                                 ownBundleIdentifier: own, targetIsRunning: running)
    }

    func testOptionClickOnFrontmostRunningAppHidesIt() {
        XCTAssertEqual(action(.option), .hideTarget)
        XCTAssertEqual(action([.option, .capsLock]), .hideTarget)
    }

    func testPlainClickLaunches() {
        XCTAssertEqual(action([]), .launch)
        XCTAssertEqual(action(.capsLock), .launch)
    }

    func testOptionClickOnBackgroundAppActivatesItAndHidesPrevious() {
        XCTAssertEqual(action(.option, front: "b"), .activateAndHide(previous: "b"))
        XCTAssertEqual(action(.option, front: "com.apple.finder"), .activateAndHide(previous: "com.apple.finder"))
    }

    func testOwnAppIsNeverHidden() {
        XCTAssertEqual(action(.option, front: "own"), .launch)
    }

    func testUnknownFrontmostLaunches() {
        XCTAssertEqual(action(.option, front: nil), .launch)
    }

    func testTerminatedTargetNeverHidesAnotherApp() {
        XCTAssertEqual(action(.option, running: false), .launch)
        XCTAssertEqual(action(.option, target: nil), .launch)
    }

    func testOtherModifierCombinationsLaunch() {
        for flags: NSEvent.ModifierFlags in [[.option, .command], [.option, .shift], [.option, .control]] {
            XCTAssertEqual(action(flags), .launch)
            XCTAssertEqual(action(flags, front: "b"), .launch)
        }
    }
}
