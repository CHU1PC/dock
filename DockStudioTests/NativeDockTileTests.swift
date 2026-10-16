import XCTest
@testable import DockStudio

final class NativeDockTileTests: XCTestCase {
    @MainActor
    func testStartingTimerSelectsFocusAndTracksElapsedTime() {
        let state = NativeDockTileState()
        let start = Date(timeIntervalSince1970: 1_000)
        state.toggle(at: start)
        state.now = start.addingTimeInterval(61)
        XCTAssertEqual(state.mode, .focus)
        XCTAssertEqual(state.timerText, "23:59")
        XCTAssertTrue(state.isRunning)
    }

    @MainActor
    func testSwitchingToClockKeepsTimerRunning() {
        let state = NativeDockTileState()
        let start = Date(timeIntervalSince1970: 1_000)
        state.toggle(at: start)
        state.mode = .clock
        state.now = start.addingTimeInterval(90)
        XCTAssertEqual(state.seconds, 1410)
        XCTAssertTrue(state.isRunning)
    }

    @MainActor
    func testPauseResumeAndReset() {
        let state = NativeDockTileState()
        let start = Date(timeIntervalSince1970: 1_000)
        state.toggle(at: start)
        state.toggle(at: start.addingTimeInterval(60))
        state.now = start.addingTimeInterval(600)
        XCTAssertEqual(state.timerText, "24:00")
        XCTAssertFalse(state.isRunning)
        state.toggle(at: state.now)
        state.now = state.now.addingTimeInterval(10)
        XCTAssertEqual(state.timerText, "23:50")
        state.reset(at: state.now)
        XCTAssertEqual(state.timerText, "25:00")
        XCTAssertFalse(state.isRunning)
    }

    @MainActor
    func testCompletionAndOneClickRestart() {
        let state = NativeDockTileState()
        let start = Date(timeIntervalSince1970: 1_000)
        state.toggle(at: start)
        state.now = start.addingTimeInterval(1600)
        XCTAssertEqual(state.status, "完了")
        XCTAssertEqual(state.timerText, "00:00")
        XCTAssertFalse(state.isRunning)
        state.toggle(at: state.now)
        XCTAssertEqual(state.timerText, "25:00")
        XCTAssertTrue(state.isRunning)
    }
}
