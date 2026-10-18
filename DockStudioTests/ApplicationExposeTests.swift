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
