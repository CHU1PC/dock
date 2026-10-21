import XCTest
@testable import DockStudio

@MainActor
final class MinimizedWindowControllerTests: XCTestCase {
    func testRefreshDisplaysWindowsReturnedByProvider() {
        let window = MinimizedWindow(id: "42:0:Budget", applicationIdentifier: "com.apple.Numbers",
                                     title: "Budget", applicationName: "Numbers", applicationIcon: nil)
        let provider = FakeMinimizedWindowProvider(state: .available([window]))
        let controller = MinimizedWindowController(provider: provider)

        controller.refresh()

        XCTAssertEqual(controller.windows.map(\.id), ["42:0:Budget"])
        XCTAssertEqual(controller.windows.first?.title, "Budget")
        XCTAssertEqual(controller.windows.first?.applicationName, "Numbers")
    }

    func testRefreshPreservesPermissionDeniedState() {
        let controller = MinimizedWindowController(provider: FakeMinimizedWindowProvider(state: .permissionDenied))

        controller.refresh()

        if case .permissionDenied = controller.state { } else { XCTFail("Expected an Accessibility permission notice") }
        XCTAssertTrue(controller.windows.isEmpty)
    }

    func testPermissionDeniedReservesOneIconSlotInDockLength() {
        let window = MinimizedWindow(id: "1", applicationIdentifier: "a", title: "t",
                                     applicationName: "n", applicationIcon: nil)
        XCTAssertEqual(MinimizedWindowState.permissionDenied.reservedSlots, 1)
        XCTAssertEqual(MinimizedWindowState.notChecked.reservedSlots, 0)
        XCTAssertEqual(MinimizedWindowState.available([window, window]).reservedSlots, 2)

        for iconSize in [32.0, 52.0, 64.0, 96.0] {
            XCTAssertEqual(
                DockMetrics.minimizedSectionLength(slots: MinimizedWindowState.permissionDenied.reservedSlots,
                                                   iconSize: iconSize),
                10 + iconSize)
        }
    }

    func testRestoreTargetsWindowAndRefreshRemovesClosedWindow() {
        let window = MinimizedWindow(id: "42:0:Budget", applicationIdentifier: "com.apple.Numbers",
                                     title: "Budget", applicationName: "Numbers", applicationIcon: nil)
        let provider = FakeMinimizedWindowProvider(state: .available([window]))
        let controller = MinimizedWindowController(provider: provider)

        controller.refresh()
        let restored = controller.restore(windowID: window.id)

        XCTAssertTrue(restored)
        XCTAssertEqual(provider.restoredWindowIDs, [window.id])
        XCTAssertTrue(controller.windows.isEmpty)
    }

    func testGroupingKeepsWindowsTogetherByApplicationAndPreservesWindowIDs() {
        let budget = MinimizedWindow(id: "42:0:Budget", applicationIdentifier: "com.apple.Numbers",
                                     title: "Budget", applicationName: "Numbers", applicationIcon: nil)
        let forecast = MinimizedWindow(id: "42:1:Forecast", applicationIdentifier: "com.apple.Numbers",
                                       title: "Forecast", applicationName: "Numbers", applicationIcon: nil)
        let notes = MinimizedWindow(id: "77:0:Notes", applicationIdentifier: "com.apple.Notes",
                                    title: "Notes", applicationName: "Notes", applicationIcon: nil)

        let groups = MinimizedWindowGrouping.groups([budget, forecast, notes])

        XCTAssertEqual(groups.map(\.applicationName), ["Notes", "Numbers"])
        XCTAssertEqual(groups.last?.windows.map(\.id), [budget.id, forecast.id])
    }

    private final class FakeMinimizedWindowProvider: MinimizedWindowProviding {
        var state: MinimizedWindowState
        var restoredWindowIDs: [String] = []

        init(state: MinimizedWindowState) {
            self.state = state
        }

        func snapshot() -> MinimizedWindowState { state }

        func restore(windowID: String) -> Bool {
            restoredWindowIDs.append(windowID)
            if case .available(let windows) = state {
                state = .available(windows.filter { $0.id != windowID })
            }
            return true
        }
    }
}
