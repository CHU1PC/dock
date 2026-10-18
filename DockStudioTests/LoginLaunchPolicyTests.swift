import Carbon
import XCTest
@testable import DockStudio

final class LoginLaunchPolicyTests: XCTestCase {
    func testLoginLaunchRestoresVisibleDockWithoutStudioWindow() {
        let decision = LoginLaunchPolicy.decision(isLoginLaunch: true, dockVisible: true)

        XCTAssertTrue(decision.showDock)
        XCTAssertFalse(decision.showStudio)
    }

    func testLoginLaunchWithHiddenDockShowsNeitherWindow() {
        let decision = LoginLaunchPolicy.decision(isLoginLaunch: true, dockVisible: false)

        XCTAssertFalse(decision.showDock)
        XCTAssertFalse(decision.showStudio)
    }

    func testNormalLaunchShowsStudioWindow() {
        let decision = LoginLaunchPolicy.decision(isLoginLaunch: false, dockVisible: false)

        XCTAssertFalse(decision.showDock)
        XCTAssertTrue(decision.showStudio)
    }

    func testLoginItemOpenApplicationEventSuppressesStudioWindow() {
        XCTAssertTrue(LoginLaunchPolicy.isLoginLaunch(
            eventID: AEEventID(kAEOpenApplication),
            propertyDataCode: OSType(keyAELaunchedAsLogInItem)
        ))
    }

    func testOpenApplicationWithoutLoginItemMarkerShowsStudioWindow() {
        XCTAssertFalse(LoginLaunchPolicy.isLoginLaunch(
            eventID: AEEventID(kAEOpenApplication),
            propertyDataCode: nil
        ))
    }

    func testOtherAppleEventWithLoginItemMarkerShowsStudioWindow() {
        XCTAssertFalse(LoginLaunchPolicy.isLoginLaunch(
            eventID: AEEventID(kAEOpenDocuments),
            propertyDataCode: OSType(keyAELaunchedAsLogInItem)
        ))
    }
}
