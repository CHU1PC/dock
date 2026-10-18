import XCTest
import SwiftUI
@testable import DockStudio

final class DockKeyboardNavigationTests: XCTestCase {
    private typealias Nav = DockKeyboardNavigation
    private let entries = [
        Nav.Entry(name: "Finder", isFocusable: true),
        Nav.Entry(name: "Mail", isFocusable: true),
        Nav.Entry(name: "", isFocusable: false),
        Nav.Entry(name: "Safari", isFocusable: true),
        Nav.Entry(name: "Slack", isFocusable: true)
    ]

    func testArrowsFollowItemAxisForEachPosition() {
        XCTAssertEqual(Nav.command(for: .left, position: .bottom), .previous)
        XCTAssertEqual(Nav.command(for: .right, position: .bottom), .next)
        XCTAssertNil(Nav.command(for: .down, position: .bottom))
        for position in [DockPosition.left, .right] {
            XCTAssertEqual(Nav.command(for: .up, position: position), .previous)
            XCTAssertEqual(Nav.command(for: .down, position: position), .next)
        }
    }

    func testMenuOpensAwayFromScreenEdge() {
        XCTAssertEqual(Nav.command(for: .up, position: .bottom), .openMenu)
        XCTAssertEqual(Nav.command(for: .right, position: .left), .openMenu)
        XCTAssertEqual(Nav.command(for: .left, position: .right), .openMenu)
        XCTAssertNil(Nav.command(for: .left, position: .left))
        XCTAssertNil(Nav.command(for: .right, position: .right))
    }

    func testOptionArrowReordersAlongDockAndIgnoresOtherDirections() {
        XCTAssertEqual(Nav.reorderOffset(for: .left, position: .bottom), -1)
        XCTAssertEqual(Nav.reorderOffset(for: .right, position: .bottom), 1)
        XCTAssertNil(Nav.reorderOffset(for: .up, position: .bottom))
        XCTAssertNil(Nav.reorderOffset(for: .down, position: .bottom))
        for position in [DockPosition.left, .right] {
            XCTAssertEqual(Nav.reorderOffset(for: .up, position: position), -1)
            XCTAssertEqual(Nav.reorderOffset(for: .down, position: position), 1)
            XCTAssertNil(Nav.reorderOffset(for: .left, position: position))
            XCTAssertNil(Nav.reorderOffset(for: .right, position: position))
        }
    }

    func testOptionArrowIgnoresNonSemanticEventModifiers() {
        let key = Nav.Key(key: .leftArrow, characters: "", modifiers: [.option, .numericPad, .function])

        XCTAssertEqual(key, .reorder(.left))
    }

    func testOptionArrowRejectsAdditionalSemanticModifiers() {
        for modifier: EventModifiers in [.shift, .control, .command] {
            let key = Nav.Key(key: .leftArrow, characters: "", modifiers: [.option, modifier, .numericPad, .function])
            XCTAssertNil(key, "Expected to reject modifier: \(modifier)")
        }
    }

    func testNextAndPreviousSkipSpacers() {
        XCTAssertEqual(Nav.outcome(.next, entries: entries, current: 1), .focus(3))
        XCTAssertEqual(Nav.outcome(.previous, entries: entries, current: 3), .focus(1))
    }

    func testEdgesLeaveWithoutWrapping() {
        XCTAssertEqual(Nav.outcome(.previous, entries: entries, current: 0), .leave)
        XCTAssertEqual(Nav.outcome(.next, entries: entries, current: 4), .leave)
    }

    func testFirstAndLast() {
        XCTAssertEqual(Nav.outcome(.first, entries: entries, current: 3), .focus(0))
        XCTAssertEqual(Nav.outcome(.last, entries: entries, current: 0), .focus(4))
    }

    func testNavigationFromNoFocusEntersAtEnds() {
        XCTAssertEqual(Nav.outcome(.next, entries: entries, current: nil), .focus(0))
        XCTAssertEqual(Nav.outcome(.previous, entries: entries, current: nil), .focus(4))
    }

    func testEmptyAndSpacerOnlyDockIgnoresNavigation() {
        XCTAssertEqual(Nav.outcome(.next, entries: [], current: nil), .ignore)
        XCTAssertEqual(Nav.outcome(.first, entries: [Nav.Entry(name: "", isFocusable: false)], current: nil), .ignore)
    }

    func testTypeAheadFindsPrefixAndCyclesSameLetter() {
        XCTAssertEqual(Nav.typeAheadIndex(prefix: "m", entries: entries, current: 0), 1)
        XCTAssertEqual(Nav.typeAheadIndex(prefix: "s", entries: entries, current: 0), 3)
        XCTAssertEqual(Nav.typeAheadIndex(prefix: "s", entries: entries, current: 3), 4)
        XCTAssertEqual(Nav.typeAheadIndex(prefix: "s", entries: entries, current: 4), 3)
    }

    func testTypeAheadWithLongerPrefixStaysOnMatchingCurrent() {
        XCTAssertEqual(Nav.typeAheadIndex(prefix: "sl", entries: entries, current: 3), 4)
        XCTAssertEqual(Nav.typeAheadIndex(prefix: "sa", entries: entries, current: 3), 3)
    }

    func testTypeAheadIgnoresCaseAndMissingNames() {
        XCTAssertEqual(Nav.typeAheadIndex(prefix: "FIN", entries: entries, current: 4), 0)
        XCTAssertNil(Nav.typeAheadIndex(prefix: "z", entries: entries, current: 0))
        XCTAssertNil(Nav.typeAheadIndex(prefix: "", entries: entries, current: 0))
    }

    func testRemovalMovesToNextThenPreviousThenNothing() {
        let after = [entries[0], entries[3], entries[4]]
        XCTAssertEqual(Nav.indexAfterRemoval(at: 1, entries: after), 1)
        XCTAssertEqual(Nav.indexAfterRemoval(at: 3, entries: after), 2)
        XCTAssertNil(Nav.indexAfterRemoval(at: 0, entries: []))
        XCTAssertNil(Nav.indexAfterRemoval(at: 0, entries: [Nav.Entry(name: "", isFocusable: false)]))
    }

    func testTypeAheadBufferAccumulatesAndExpires() {
        var buffer = DockTypeAheadBuffer()
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(buffer.append("s", at: start), "s")
        XCTAssertEqual(buffer.append("l", at: start.addingTimeInterval(0.5)), "sl")
        XCTAssertEqual(buffer.append("m", at: start.addingTimeInterval(0.5 + DockTypeAheadBuffer.timeout + 0.1)), "m")
    }

    func testItemMenuKindsFollowItemState() {
        typealias Menu = DockItemMenu
        XCTAssertEqual(Menu.kinds(hasFileURL: true, canQuit: true, isPinned: true), [.open, .reveal, .quit, .forceQuit, .remove])
        XCTAssertEqual(Menu.kinds(hasFileURL: true, canQuit: false, isPinned: false), [.open, .reveal, .keep])
        XCTAssertEqual(Menu.kinds(hasFileURL: false, canQuit: false, isPinned: true), [.open, .remove])
        XCTAssertEqual(Menu.kinds(hasFileURL: false, canQuit: true, isPinned: false), [.open, .quit, .forceQuit, .keep])
        XCTAssertEqual(Menu.kinds(hasFileURL: true, visibility: .visible, canQuit: true, isPinned: true), [.open, .reveal, .hide, .quit, .forceQuit, .remove])
        XCTAssertEqual(Menu.kinds(hasFileURL: false, visibility: .hidden, canQuit: true, isPinned: false), [.open, .show, .quit, .forceQuit, .keep])
    }

    func testAccessibilityActionsExcludeOpenAndReveal() {
        let kinds = DockItemMenu.kinds(hasFileURL: true, canQuit: true, isPinned: true)
        XCTAssertEqual(kinds.filter(\.isAccessibilityAction), [.quit, .forceQuit, .remove])
    }
}
