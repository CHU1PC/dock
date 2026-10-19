import XCTest
@testable import DockStudio

final class DockDragOutRemovalTests: XCTestCase {
    private let margin = DockDragOutRemoval.margin

    func testStateMachineEndsAfterDropInside() {
        assertDragEnds(for: .dropInside)
    }

    func testStateMachineEndsAfterDropOutsideRemoval() {
        assertDragEnds(for: .dropOutsideRemoval)
    }

    func testEscapeCancellationEndsDrag() {
        var state = DockDragOutStateMachine()
        state.begin()

        XCTAssertTrue(state.cancelIfDragging())
        XCTAssertTrue(state.finish(.cancelled))
        XCTAssertFalse(state.isDragging)
        XCTAssertFalse(state.isCancelled)
    }

    func testGlobalMouseUpEndsDropOnTrash() {
        assertDragEnds(for: .externalDrop)
    }

    func testGlobalMouseUpEndsDropOnApplication() {
        assertDragEnds(for: .externalDrop)
    }

    func testDragCompletionReleasesKeyboardFocusPinSoAutoHideCanResume() {
        XCTAssertTrue(DockDragOutRemoval.shouldRelinquishKeyboardFocusAfterDrag(panelIsKey: true))
        XCTAssertFalse(DockDragOutRemoval.shouldRelinquishKeyboardFocusAfterDrag(panelIsKey: false))

        var visibility = DockVisibilityState()
        let start = Date(timeIntervalSince1970: 100)
        visibility.update(visible: true, autoHide: true, hovering: false, interacting: true, now: start)
        visibility.update(visible: true, autoHide: true, hovering: false, interacting: false,
                          now: start.addingTimeInterval(1.1))
        XCTAssertTrue(visibility.isCollapsed)
    }

    func testAutoHideStaysExpandedDuringDragAndResumesAfterward() {
        var drag = DockDragOutStateMachine()
        var visibility = DockVisibilityState()
        let start = Date(timeIntervalSince1970: 100)

        visibility.update(visible: true, autoHide: true, hovering: false, interacting: false, now: start)
        drag.begin()
        visibility.update(visible: true, autoHide: true, hovering: false,
                          interacting: drag.isDragging, now: start.addingTimeInterval(1.1))
        XCTAssertFalse(visibility.isCollapsed)

        _ = drag.finish(.dropOutsideRemoval)
        visibility.update(visible: true, autoHide: true, hovering: false,
                          interacting: drag.isDragging, now: start.addingTimeInterval(1.5))
        XCTAssertFalse(visibility.isCollapsed)
        visibility.update(visible: true, autoHide: true, hovering: false,
                          interacting: drag.isDragging, now: start.addingTimeInterval(2.2))
        XCTAssertTrue(visibility.isCollapsed)
    }

    func testDragKeepsPanelReceivingEventsAndRestoresPassThroughAfterward() {
        XCTAssertFalse(DockDragOutRemoval.shouldIgnoreMouseEvents(
            pointerIsInteractive: false, trackingMenus: false,
            hasActivePopover: false, isDragging: true))
        XCTAssertTrue(DockDragOutRemoval.shouldIgnoreMouseEvents(
            pointerIsInteractive: false, trackingMenus: false,
            hasActivePopover: false, isDragging: false))
        XCTAssertFalse(DockDragOutRemoval.shouldIgnoreMouseEvents(
            pointerIsInteractive: false, trackingMenus: true,
            hasActivePopover: false, isDragging: false))
    }

    func testBottomVisibleBoundsExcludeTransparentLabelArea() {
        // パネルの下配置: DockBar の高さは icon+65、見える背景は icon+30（icon=64）
        let bounds = DockDragOutRemoval.visibleBounds(barSize: CGSize(width: 400, height: 129), vertical: false, thickness: 94)
        XCTAssertEqual(bounds, CGRect(x: 0, y: 35, width: 400, height: 94))
    }

    func testVerticalVisibleBoundsAreCenteredInPreviewWidth() {
        // プレビューの左右配置: 幅 190 の中に barThickness の背景が中央にある
        let bounds = DockDragOutRemoval.visibleBounds(barSize: CGSize(width: 190, height: 300), vertical: true, thickness: 174)
        XCTAssertEqual(bounds, CGRect(x: 8, y: 0, width: 174, height: 300))
    }

    func testVerticalVisibleBoundsFillPanelWidth() {
        let bounds = DockDragOutRemoval.visibleBounds(barSize: CGSize(width: 174, height: 300), vertical: true, thickness: 174)
        XCTAssertEqual(bounds, CGRect(x: 0, y: 0, width: 174, height: 300))
    }

    func testThicknessLargerThanBarIsClamped() {
        let bounds = DockDragOutRemoval.visibleBounds(barSize: CGSize(width: 400, height: 80), vertical: false, thickness: 94)
        XCTAssertEqual(bounds, CGRect(x: 0, y: 0, width: 400, height: 80))
    }

    func testUnmeasuredBarHasNoBoundsAndNeverRemoves() {
        let bounds = DockDragOutRemoval.visibleBounds(barSize: .zero, vertical: false, thickness: 94)
        XCTAssertTrue(bounds.isEmpty)
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 900, y: 900), bounds: bounds))
    }

    func testBottomPanelJudgesFromVisibleBackground() {
        let bounds = DockDragOutRemoval.visibleBounds(barSize: CGSize(width: 400, height: 129), vertical: false, thickness: 94)
        // 透明領域の中（背景の上端から margin 以内）は外ではない
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: 35 - margin), bounds: bounds))
        // 背景の上端から margin を超えると外になる（DockBar 全体の矩形なら内側の位置）
        XCTAssertTrue(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: 35 - margin - 1), bounds: bounds))
        XCTAssertTrue(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: 10), bounds: bounds))
    }

    func testVerticalPreviewJudgesFromVisibleBackground() {
        let bounds = DockDragOutRemoval.visibleBounds(barSize: CGSize(width: 190, height: 300), vertical: true, thickness: 174)
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 8 - margin, y: 150), bounds: bounds))
        XCTAssertTrue(DockDragOutRemoval.isOutside(location: CGPoint(x: 8 - margin - 1, y: 150), bounds: bounds))
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 100, y: 150), bounds: bounds))
    }

    func testInnerEdgesBoundaryUsesHalfOpenRect() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 80)
        // contains は max 辺を含まない: 右端は x = 412、下端は y = 92 で外になる
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 411, y: 40), bounds: bounds))
        XCTAssertTrue(DockDragOutRemoval.isOutside(location: CGPoint(x: 412, y: 40), bounds: bounds))
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: 91), bounds: bounds))
        XCTAssertTrue(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: 92), bounds: bounds))
        // min 辺は含む
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: -12, y: -12), bounds: bounds))
        XCTAssertTrue(DockDragOutRemoval.isOutside(location: CGPoint(x: -13, y: 40), bounds: bounds))
    }

    func testExplicitMarginArgument() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 80)
        XCTAssertTrue(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: -1), bounds: bounds, margin: 0))
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: -1), bounds: bounds, margin: 5))
        XCTAssertFalse(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: 84), bounds: bounds, margin: 5))
        XCTAssertTrue(DockDragOutRemoval.isOutside(location: CGPoint(x: 200, y: 85), bounds: bounds, margin: 5))
    }

    private func assertDragEnds(for reason: DockDragOutStateMachine.EndReason,
                                file: StaticString = #filePath, line: UInt = #line) {
        var state = DockDragOutStateMachine()
        state.begin()

        XCTAssertFalse(state.finish(reason), file: file, line: line)
        XCTAssertFalse(state.isDragging, file: file, line: line)
        XCTAssertFalse(state.isCancelled, file: file, line: line)
    }
}
