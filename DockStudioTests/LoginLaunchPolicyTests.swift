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

    func testLoginLaunchWithVisibleDockShowsOnlyDock() {
        let decision = LoginLaunchPolicy.decision(isLoginLaunch: true, dockVisible: true)

        XCTAssertTrue(decision.showDock)
        XCTAssertFalse(decision.showStudio)
    }

    func testNormalLaunchShowsStudioWindow() {
        let decision = LoginLaunchPolicy.decision(isLoginLaunch: false, dockVisible: false)

        XCTAssertFalse(decision.showDock)
        XCTAssertTrue(decision.showStudio)
    }

    func testNormalLaunchWithVisibleDockShowsBoth() {
        let decision = LoginLaunchPolicy.decision(isLoginLaunch: false, dockVisible: true)

        XCTAssertTrue(decision.showDock)
        XCTAssertTrue(decision.showStudio)
    }

    func testLoginEventArrivingAfterInitialDecisionChangesPolicy() {
        var eventState = LoginLaunchPolicy.EventState()
        let initialDecision = LoginLaunchPolicy.decision(
            isLoginLaunch: eventState.usesLoginLaunchBehavior,
            dockVisible: true
        )
        XCTAssertTrue(initialDecision.showStudio)

        eventState.record(isLoginLaunch: true)
        let lateDecision = LoginLaunchPolicy.decision(
            isLoginLaunch: eventState.usesLoginLaunchBehavior,
            dockVisible: true
        )
        XCTAssertTrue(lateDecision.showDock)
        XCTAssertFalse(lateDecision.showStudio)
    }

    func testLoginEventArrivingBeforeInitialDecisionIsUsed() {
        var eventState = LoginLaunchPolicy.EventState()
        eventState.record(isLoginLaunch: true)
        let decision = LoginLaunchPolicy.decision(
            isLoginLaunch: eventState.usesLoginLaunchBehavior,
            dockVisible: true
        )

        XCTAssertTrue(decision.showDock)
        XCTAssertFalse(decision.showStudio)
    }

    func testMissingLaunchEventUsesNormalLaunchPolicy() {
        let eventState = LoginLaunchPolicy.EventState()
        let decision = LoginLaunchPolicy.decision(
            isLoginLaunch: eventState.usesLoginLaunchBehavior,
            dockVisible: false
        )

        XCTAssertFalse(decision.showDock)
        XCTAssertTrue(decision.showStudio)
    }

    func testLateLoginEventWithHiddenDockStillSuppressesStudioWindow() {
        var eventState = LoginLaunchPolicy.EventState()
        eventState.record(isLoginLaunch: true)
        let decision = LoginLaunchPolicy.decision(
            isLoginLaunch: eventState.usesLoginLaunchBehavior,
            dockVisible: false
        )

        XCTAssertFalse(decision.showDock)
        XCTAssertFalse(decision.showStudio)
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
