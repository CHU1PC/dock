import Carbon
import XCTest
@testable import DockStudio

final class LoginLaunchPolicyTests: XCTestCase {
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
