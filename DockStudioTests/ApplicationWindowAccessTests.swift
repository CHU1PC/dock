import XCTest
@testable import DockStudio

private final class FakeApplicationWindowProvider: ApplicationWindowProviding {
    var listing: ApplicationWindowListing = .windows([])
    private(set) var requestedBundleIdentifiers: [String] = []
    private(set) var promptFlags: [Bool] = []
    private(set) var activatedWindowIDs: [String] = []
    var activationSucceeds = true

    func windows(for bundleIdentifier: String, promptForAccess: Bool) -> ApplicationWindowListing {
        requestedBundleIdentifiers.append(bundleIdentifier)
        promptFlags.append(promptForAccess)
        return listing
    }

    func activateWindow(id: String, for bundleIdentifier: String) -> Bool {
        activatedWindowIDs.append("\(bundleIdentifier):\(id)")
        return activationSucceeds
    }
}

final class ApplicationWindowAccessTests: XCTestCase {
    func testListsWindowsForTheRequestedApplication() {
        let provider = FakeApplicationWindowProvider()
        let windows = [ApplicationWindow(id: "1", title: "Document", isMinimized: false),
                       ApplicationWindow(id: "2", title: "Document", isMinimized: true)]
        provider.listing = .windows(windows)
        let access = ApplicationWindowAccess(provider: provider)

        XCTAssertEqual(access.windows(for: "com.example.editor"), .windows(windows))
        XCTAssertEqual(provider.requestedBundleIdentifiers, ["com.example.editor"])
    }

    func testPermissionDenialIsPreservedAsAnExplicitResult() {
        let provider = FakeApplicationWindowProvider()
        provider.listing = .accessibilityPermissionDenied
        let access = ApplicationWindowAccess(provider: provider)

        XCTAssertEqual(access.windows(for: "com.example.editor"), .accessibilityPermissionDenied)
    }

    func testActivatesTheSelectedWindowForItsApplication() {
        let provider = FakeApplicationWindowProvider()
        let access = ApplicationWindowAccess(provider: provider)

        XCTAssertTrue(access.activate(windowID: "2", for: "com.example.editor"))
        XCTAssertEqual(provider.activatedWindowIDs, ["com.example.editor:2"])
    }

    func testActivationFailureIsReported() {
        let provider = FakeApplicationWindowProvider()
        provider.activationSucceeds = false
        let access = ApplicationWindowAccess(provider: provider)

        XCTAssertFalse(access.activate(windowID: "2", for: "com.example.editor"))
    }

    func testAccessibilityListingNeverPromptsForPermission() {
        let provider = FakeApplicationWindowProvider()
        let access = ApplicationWindowAccess(provider: provider)

        _ = access.windows(for: "com.example.editor")
        _ = access.windows(for: "com.example.editor", promptForAccess: false)

        XCTAssertEqual(provider.promptFlags, [true, false])
    }
}
