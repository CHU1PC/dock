import Foundation

enum DockTrashDivider {
    static func spacerDrawsLine(index: Int, itemCount: Int) -> Bool {
        index != itemCount - 1
    }

    static func linesDirectlyBeforeTrash(items: [DockItem], dividerBefore: Set<Int>) -> Int {
        let resizeHandleLine = 1
        guard let last = items.last else { return resizeHandleLine }
        let spacerLine = last.kind == .spacer && spacerDrawsLine(index: items.count - 1, itemCount: items.count) ? 1 : 0
        let layoutLine = dividerBefore.contains(items.count) ? 1 : 0
        return resizeHandleLine + spacerLine + layoutLine
    }
}
