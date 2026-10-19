import XCTest
@testable import DockStudio

private final class FakeApplicationExposer: ApplicationExposing {
    var isAccessibilityTrusted = true
    var result: ApplicationExposeResult = .opened
    private(set) var requestedURLs: [URL] = []

    func showAllWindows(for applicationURL: URL) -> ApplicationExposeResult {
        requestedURLs.append(applicationURL)
        return result
    }
}

final class ApplicationExposeTests: XCTestCase {
    func testMatchesCryptexDockURLByBundleIdentifier() {
        let targetURL = URL(fileURLWithPath: "/Applications/Safari.app")
        let cryptexURL = URL(fileURLWithPath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app")

        XCTAssertTrue(ApplicationExposeMatcher.matches(
            targetURL: targetURL,
            targetBundleIdentifier: "com.apple.Safari",
            targetTitle: "Safari",
            dockURL: cryptexURL,
            dockBundleIdentifier: "com.apple.Safari",
            dockTitle: "Safari"
        ))
        XCTAssertEqual(
            ApplicationExposeMatcher.normalizedPath(cryptexURL.path),
            "/System/Applications/Safari.app"
        )
    }

    func testMatchesStandardApplicationsDockURLByNormalizedPath() {
        let applicationURL = URL(fileURLWithPath: "/Applications/Example.app")

        XCTAssertTrue(ApplicationExposeMatcher.matches(
            targetURL: applicationURL,
            targetBundleIdentifier: nil,
            targetTitle: "Example",
            dockURL: applicationURL,
            dockBundleIdentifier: nil,
            dockTitle: "Example"
        ))
    }

    func testFallsBackToDockTitleWhenDockURLIsMissing() {
        XCTAssertTrue(ApplicationExposeMatcher.matches(
            targetURL: URL(fileURLWithPath: "/Applications/System Settings.app"),
            targetBundleIdentifier: "com.apple.systempreferences",
            targetTitle: "System Settings",
            dockURL: nil,
            dockBundleIdentifier: nil,
            dockTitle: "System Settings"
        ))
    }

    func testDoesNotMatchApplicationsWithSimilarTitles() {
        XCTAssertFalse(ApplicationExposeMatcher.matches(
            targetURL: URL(fileURLWithPath: "/Applications/Safari.app"),
            targetBundleIdentifier: "com.apple.Safari",
            targetTitle: "Safari",
            dockURL: nil,
            dockBundleIdentifier: nil,
            dockTitle: "Safari Technology Preview"
        ))
    }

    func testRecognizesEnglishAndJapaneseDockMenuTitles() {
        XCTAssertTrue(StandardDockExposeMenu.matches(title: "Show All Windows", languageCode: "en"))
        XCTAssertTrue(StandardDockExposeMenu.matches(title: "すべてのウインドウを表示", languageCode: "ja"))
        XCTAssertTrue(StandardDockExposeMenu.matches(title: "すべてのウィンドウを表示", languageCode: "ja"))
    }

    func testUnknownLanguageAndSimilarTitlesFailClosed() {
        XCTAssertFalse(StandardDockExposeMenu.matches(title: "Show All Windows", languageCode: "fr"))
        XCTAssertFalse(StandardDockExposeMenu.matches(title: "All Windows", languageCode: "en"))
        XCTAssertFalse(StandardDockExposeMenu.matches(title: "Show All Windows Now", languageCode: "en"))
    }

    func testPlanUsesShowExposeActionWhenDockItemOffersIt() {
        XCTAssertEqual(
            StandardDockExposePlan.plan(actionNames: ["AXPress", "AXShowMenu", "AXShowExpose"]),
            .performAction("AXShowExpose")
        )
    }

    func testPlanFallsBackToMenuItemWithoutShowExposeAction() {
        XCTAssertEqual(StandardDockExposePlan.plan(actionNames: ["AXPress", "AXShowMenu"]), .chooseMenuItem)
        XCTAssertEqual(StandardDockExposePlan.plan(actionNames: []), .chooseMenuItem)
    }

    func testMenuPollingWaitsLongerThanOneImmediateRead() {
        XCTAssertGreaterThan(StandardDockExposePlan.menuPollTimeout, StandardDockExposePlan.menuPollInterval * 10)
    }

    func testAppExposeActionIsLabeledSeparatelyFromIndividualWindowList() {
        XCTAssertEqual(DockItemMenu.Kind.showAllWindows.title, "全ウィンドウを表示")
        XCTAssertNotEqual(DockItemMenu.Kind.showAllWindows.title, "ウィンドウを前面に表示")
    }

    func testPassesRequestedApplicationURLAndResultThroughAccessLayer() {
        let provider = FakeApplicationExposer()
        let access = ApplicationExposeAccess(provider: provider)
        let url = URL(fileURLWithPath: "/Applications/Example.app")

        XCTAssertTrue(access.isAccessibilityTrusted)
        XCTAssertEqual(access.showAllWindows(for: url), .opened)
        XCTAssertEqual(provider.requestedURLs, [url])

        provider.isAccessibilityTrusted = false
        provider.result = .accessibilityPermissionDenied
        XCTAssertFalse(access.isAccessibilityTrusted)
        XCTAssertEqual(access.showAllWindows(for: url), .accessibilityPermissionDenied)
    }
}
