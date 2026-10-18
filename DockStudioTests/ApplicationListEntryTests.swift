import XCTest
@testable import DockStudio

final class ApplicationListEntryTests: XCTestCase {
    func testMacOS15EntryExistsOnlyWhenLaunchpadResolves() {
        let url = URL(fileURLWithPath: "/System/Applications/Launchpad.app")
        let item = ApplicationListEntry.item(osMajorVersion: 15) { identifier in
            identifier == "com.apple.launchpad.launcher" ? url : nil
        }

        XCTAssertEqual(item?.name, "Launchpad")
        XCTAssertEqual(item?.bundleIdentifier, "com.apple.launchpad.launcher")
        XCTAssertNil(item?.target)
    }

    func testMacOS26EntryExistsOnlyWhenAppsResolves() {
        let url = URL(fileURLWithPath: "/System/Applications/Apps.app")
        let item = ApplicationListEntry.item(osMajorVersion: 26) { identifier in
            identifier == "com.apple.apps.launcher" ? url : nil
        }

        XCTAssertEqual(item?.name, "アプリ一覧")
        XCTAssertEqual(item?.bundleIdentifier, "com.apple.apps.launcher")
        XCTAssertNil(item?.target)
    }

    func testUnsupportedOrUnavailableOSHasNoEntry() {
        XCTAssertNil(ApplicationListEntry.item(osMajorVersion: 15) { _ in nil })
        XCTAssertNil(ApplicationListEntry.item(osMajorVersion: 26) { _ in nil })
        XCTAssertNil(ApplicationListEntry.item(osMajorVersion: 16) { _ in URL(fileURLWithPath: "/tmp") })
    }

    func testStoredEntryUsesCurrentOSIdentifierAndDoesNotRetainItsOldPath() {
        let stored = DockItem(name: "Launchpad", kind: .applicationList,
                              target: "file:///System/Applications/Launchpad.app",
                              bundleIdentifier: "com.apple.launchpad.launcher")
        let current = ApplicationListEntry.currentItem(for: stored, osMajorVersion: 26) { identifier in
            identifier == "com.apple.apps.launcher"
                ? URL(fileURLWithPath: "/System/Applications/Apps.app") : nil
        }

        XCTAssertEqual(current?.name, "アプリ一覧")
        XCTAssertEqual(current?.bundleIdentifier, "com.apple.apps.launcher")
        XCTAssertNil(current?.target)
    }

    func testStoredEntryIsHiddenWhenCurrentOSHasNoResolvableEntry() {
        let stored = DockItem(name: "アプリ一覧", kind: .applicationList,
                              bundleIdentifier: "com.apple.apps.launcher")

        XCTAssertNil(ApplicationListEntry.currentItem(for: stored, osMajorVersion: 26) { _ in nil })
    }
}
