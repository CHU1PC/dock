import XCTest
@testable import DockStudio

final class AutoHideKeyWindowTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    private func interacting(keyboardFocusActive: Bool = false, isDragging: Bool = false) -> Bool {
        DockVisibilityState.isInteracting(trackingMenus: false, hasActivePopover: false,
                                          keyboardFocusActive: keyboardFocusActive,
                                          keyboardFocusRequested: false, isDragging: isDragging)
    }

    private func settle(_ state: inout DockVisibilityState, interacting: Bool, from t: TimeInterval, to end: TimeInterval) {
        var t = t
        while t <= end {
            state.update(visible: true, autoHide: true, hovering: false, interacting: interacting,
                         now: start.addingTimeInterval(t))
            t += 0.1
        }
    }

    func testPanelBecomingKeyAfterDragRemovalDoesNotKeepDockOpen() {
        var state = DockVisibilityState()
        settle(&state, interacting: false, from: 0, to: 0.5)
        settle(&state, interacting: interacting(isDragging: true), from: 0.6, to: 2)
        XCTAssertFalse(state.isCollapsed)

        settle(&state, interacting: interacting(), from: 2.1, to: 4)
        XCTAssertTrue(state.isCollapsed)
    }

    func testKeyboardFocusKeepsDockOpen() {
        XCTAssertTrue(interacting(keyboardFocusActive: true))
    }

    func testDragKeepsDockOpen() {
        XCTAssertTrue(interacting(isDragging: true))
    }

    func testMenuPopoverAndFocusRequestKeepDockOpen() {
        XCTAssertTrue(DockVisibilityState.isInteracting(trackingMenus: true, hasActivePopover: false,
                                                        keyboardFocusActive: false, keyboardFocusRequested: false, isDragging: false))
        XCTAssertTrue(DockVisibilityState.isInteracting(trackingMenus: false, hasActivePopover: true,
                                                        keyboardFocusActive: false, keyboardFocusRequested: false, isDragging: false))
        XCTAssertTrue(DockVisibilityState.isInteracting(trackingMenus: false, hasActivePopover: false,
                                                        keyboardFocusActive: false, keyboardFocusRequested: true, isDragging: false))
    }
}
