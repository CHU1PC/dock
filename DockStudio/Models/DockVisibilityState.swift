import Foundation

struct DockVisibilityState {
    private(set) var isCollapsed = false
    private var wasVisible = false
    private var wasEnabled = false
    private var lastInteraction = Date.distantPast

    mutating func update(visible: Bool, autoHide: Bool, hovering: Bool, interacting: Bool,
                         draggingOverRevealArea: Bool = false, now: Date) {
        if !visible || !autoHide || !wasVisible || !wasEnabled {
            isCollapsed = false
            lastInteraction = now
        } else if hovering || interacting || draggingOverRevealArea {
            isCollapsed = false
            lastInteraction = now
        } else if now.timeIntervalSince(lastInteraction) >= 1 {
            isCollapsed = true
        }
        wasVisible = visible
        wasEnabled = autoHide
    }
}
