import XCTest
@testable import DockStudio

private final class FakeFocusStatusProvider: FocusStatusProviding {
    var authorization: FocusStatusAuthorization = .notDetermined
    var isFocused: Bool?
    private(set) var authorizationRequests = 0

    func requestAuthorization(completion: @escaping (FocusStatusAuthorization) -> Void) {
        authorizationRequests += 1
        completion(authorization)
    }
}

final class AttentionBounceTests: XCTestCase {
    func testSettingDefaultsToEnabledAndRoundTrips() throws {
        let settings = DockSettings()

        XCTAssertTrue(settings.attentionBounce)
        XCTAssertEqual(try JSONDecoder().decode(DockSettings.self, from: JSONEncoder().encode(settings)), settings)
    }

    func testDetectsIsolatedRepeatedDockFrameMovement() {
        let frames = [100.0, 78, 100, 76, 100].map { CGRect(x: 20, y: $0, width: 48, height: 48) }

        XCTAssertTrue(AttentionBouncePolicy.isBounce(frames: frames, peerMoved: false))
    }

    func testRejectsMovementSharedByDockItems() {
        let frames = [100.0, 78, 100, 76, 100].map { CGRect(x: 20, y: $0, width: 48, height: 48) }

        XCTAssertFalse(AttentionBouncePolicy.isBounce(frames: frames, peerMoved: true))
    }

    func testRejectsMagnificationThatChangesFrameSize() {
        let frames = [48.0, 55, 62, 55, 48].map { CGRect(x: 20, y: 100, width: 48, height: $0) }

        XCTAssertFalse(AttentionBouncePolicy.isBounce(frames: frames, peerMoved: false))
    }

    func testRequiresRepeatedMovementAndEnoughAmplitude() {
        let smallFrames = [100.0, 94, 100, 94, 100].map { CGRect(x: 20, y: $0, width: 48, height: 48) }
        let oneBounce = [100.0, 75, 100, 100, 100].map { CGRect(x: 20, y: $0, width: 48, height: 48) }

        XCTAssertFalse(AttentionBouncePolicy.isBounce(frames: smallFrames, peerMoved: false))
        XCTAssertFalse(AttentionBouncePolicy.isBounce(frames: oneBounce, peerMoved: false))
    }

    func testRequiresAccessibilityAndObservableDockItem() {
        let now = Date()

        XCTAssertFalse(AttentionBouncePolicy.shouldDisplay(isBounce: true, accessibilityTrusted: false,
                                                             isObservable: true, launchedAt: nil,
                                                             lastDisplayedAt: nil, now: now))
        XCTAssertFalse(AttentionBouncePolicy.shouldDisplay(isBounce: true, accessibilityTrusted: true,
                                                             isObservable: false, launchedAt: nil,
                                                             lastDisplayedAt: nil, now: now))
    }

    func testSuppressesRecentLaunchAndRateLimitsRepeatedRequests() {
        let now = Date()

        XCTAssertFalse(AttentionBouncePolicy.shouldDisplay(isBounce: true, accessibilityTrusted: true,
                                                             isObservable: true,
                                                             launchedAt: now.addingTimeInterval(-10),
                                                             lastDisplayedAt: nil, now: now))
        XCTAssertFalse(AttentionBouncePolicy.shouldDisplay(isBounce: true, accessibilityTrusted: true,
                                                             isObservable: true, launchedAt: nil,
                                                             lastDisplayedAt: now.addingTimeInterval(-5), now: now))
        XCTAssertTrue(AttentionBouncePolicy.shouldDisplay(isBounce: true, accessibilityTrusted: true,
                                                            isObservable: true, launchedAt: nil,
                                                            lastDisplayedAt: now.addingTimeInterval(-11), now: now))
    }

    func testSuppressesBounceOnlyWhenFocusStatusIsAuthorizedAndFocused() {
        let provider = FakeFocusStatusProvider()
        let focusStatus = AttentionBounceFocusStatus(provider: provider)

        provider.authorization = .authorized
        provider.isFocused = true
        XCTAssertTrue(focusStatus.shouldSuppressBounce)

        provider.isFocused = false
        XCTAssertFalse(focusStatus.shouldSuppressBounce)
        provider.isFocused = nil
        XCTAssertFalse(focusStatus.shouldSuppressBounce)
        provider.authorization = .denied
        provider.isFocused = true
        XCTAssertFalse(focusStatus.shouldSuppressBounce)
        provider.authorization = .unavailable
        XCTAssertFalse(focusStatus.shouldSuppressBounce)
    }

    func testRequestsFocusAuthorizationOnceWhenStatusIsUndetermined() {
        let provider = FakeFocusStatusProvider()
        let focusStatus = AttentionBounceFocusStatus(provider: provider)

        focusStatus.requestAuthorizationIfNeeded()
        focusStatus.requestAuthorizationIfNeeded()

        XCTAssertEqual(provider.authorizationRequests, 1)
    }

    func testDeniedOrUnavailableFocusStatusKeepsBounceDisplayEnabled() {
        let now = Date()
        let provider = FakeFocusStatusProvider()
        let focusStatus = AttentionBounceFocusStatus(provider: provider)

        for authorization in [FocusStatusAuthorization.denied, .unavailable] {
            provider.authorization = authorization
            provider.isFocused = true
            XCTAssertTrue(AttentionBouncePolicy.shouldDisplay(isBounce: true, accessibilityTrusted: true,
                                                                isObservable: true, launchedAt: nil,
                                                                lastDisplayedAt: nil, now: now,
                                                                suppressForFocus: focusStatus.shouldSuppressBounce))
        }
    }
}
