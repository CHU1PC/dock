import XCTest
@testable import DockStudio

final class ApplicationDockMenuAccessTests: XCTestCase {
    func testMenuReturnsProviderEntriesForApplication() {
        let entries = [ApplicationDockMenuItem(id: "0", title: "新規ウインドウ", children: [])]
        let provider = FakeApplicationDockMenuProvider(menu: entries)
        let access = ApplicationDockMenuAccess(provider: provider)
        let url = URL(fileURLWithPath: "/Applications/Safari.app")

        XCTAssertEqual(access.menu(for: url), entries)
        XCTAssertEqual(provider.requestedURLs, [url])
    }

    func testMissingMenuRemainsUnavailableForFixedMenuFallback() {
        let provider = FakeApplicationDockMenuProvider(menu: nil)
        let access = ApplicationDockMenuAccess(provider: provider)

        XCTAssertNil(access.menu(for: URL(fileURLWithPath: "/Applications/Safari.app")))
    }

    func testPerformTargetsSelectedMenuEntry() {
        let provider = FakeApplicationDockMenuProvider(menu: [])
        provider.performResult = true
        let access = ApplicationDockMenuAccess(provider: provider)
        let url = URL(fileURLWithPath: "/Applications/Safari.app")

        XCTAssertTrue(access.perform(itemID: "0.1", for: url))
        XCTAssertEqual(provider.performedEntries, ["0.1"])
        XCTAssertEqual(provider.requestedURLs, [url])
    }

    private final class FakeApplicationDockMenuProvider: ApplicationDockMenuProviding {
        let menuResult: [ApplicationDockMenuItem]?
        var performResult = false
        var requestedURLs: [URL] = []
        var performedEntries: [String] = []

        init(menu: [ApplicationDockMenuItem]?) {
            menuResult = menu
        }

        func menu(for applicationURL: URL) -> [ApplicationDockMenuItem]? {
            requestedURLs.append(applicationURL)
            return menuResult
        }

        func perform(itemID: String, for applicationURL: URL) -> Bool {
            requestedURLs.append(applicationURL)
            performedEntries.append(itemID)
            return performResult
        }
    }
}
