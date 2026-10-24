import Foundation

struct DockVisibilityState {
    private(set) var isCollapsed = false
    private var wasVisible = false
    private var wasEnabled = false
    private var lastInteraction = Date.distantPast

    /// パネルがキーウィンドウであるだけでは操作中とみなさない。キー状態は OS が非アクティブ時にも与え直すため、折り畳みが止まり続ける。
    static func isInteracting(trackingMenus: Bool, hasActivePopover: Bool, keyboardFocusActive: Bool,
                              keyboardFocusRequested: Bool, isDragging: Bool) -> Bool {
        trackingMenus || hasActivePopover || keyboardFocusActive || keyboardFocusRequested || isDragging
    }

    static func hasHideDelayElapsed(since lastInteraction: Date, now: Date, delay: TimeInterval) -> Bool {
        guard delay.isFinite, DockSettings.hideDelayRange.contains(delay) else { return false }
        return now.timeIntervalSince(lastInteraction) >= delay
    }

    mutating func update(visible: Bool, autoHide: Bool, hovering: Bool, interacting: Bool,
                         draggingOverRevealArea: Bool = false,
                         hideDelay: TimeInterval = DockSettings.defaultHideDelay, now: Date) {
        if !visible || !autoHide || !wasVisible || !wasEnabled {
            isCollapsed = false
            lastInteraction = now
        } else if hovering || interacting || draggingOverRevealArea {
            isCollapsed = false
            lastInteraction = now
        } else if Self.hasHideDelayElapsed(since: lastInteraction, now: now, delay: hideDelay) {
            isCollapsed = true
        }
        wasVisible = visible
        wasEnabled = autoHide
    }
}
