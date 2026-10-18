import Foundation
import SwiftUI

enum DockKeyboardNavigation {
    enum Arrow { case up, down, left, right }
    enum Key: Equatable { case arrow(Arrow), home, end, character(String) }
    enum Command: Equatable { case previous, next, first, last, openMenu }
    enum Outcome: Equatable { case focus(Int), leave, ignore }

    struct Entry: Equatable {
        var name: String
        var isFocusable: Bool
    }

    static func shouldAdvanceKeyView(isWindowKey: Bool, firstResponderIsDockContainer: Bool) -> Bool {
        isWindowKey && firstResponderIsDockContainer
    }

    /// 項目の並びに沿う矢印が前後の移動になり、画面の端から離れる向きがメニューになる。
    static func command(for arrow: Arrow, position: DockPosition) -> Command? {
        switch (position, arrow) {
        case (.bottom, .left), (.left, .up), (.right, .up): .previous
        case (.bottom, .right), (.left, .down), (.right, .down): .next
        case (.bottom, .up), (.left, .right), (.right, .left): .openMenu
        default: nil
        }
    }

    static func outcome(_ command: Command, entries: [Entry], current: Int?) -> Outcome {
        let indices = entries.indices.filter { entries[$0].isFocusable }
        switch command {
        case .first: return indices.first.map(Outcome.focus) ?? .ignore
        case .last: return indices.last.map(Outcome.focus) ?? .ignore
        case .openMenu: return .ignore
        case .next, .previous:
            guard let current else {
                return (command == .next ? indices.first : indices.last).map(Outcome.focus) ?? .ignore
            }
            let target = command == .next ? indices.first { $0 > current } : indices.last { $0 < current }
            return target.map(Outcome.focus) ?? .leave
        }
    }

    /// 1文字目は現在の項目の次から、続けて入力した文字列は現在の項目から探し、端で折り返す。
    static func typeAheadIndex(prefix: String, entries: [Entry], current: Int?) -> Int? {
        guard !prefix.isEmpty, !entries.isEmpty else { return nil }
        let start = current.map { prefix.count > 1 ? $0 : $0 + 1 } ?? 0
        for offset in 0..<entries.count {
            let index = (start + offset) % entries.count
            if entries[index].isFocusable,
               entries[index].name.range(of: prefix, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil {
                return index
            }
        }
        return nil
    }

    /// 取り外した項目の位置にあった次の項目を優先し、無ければひとつ前に移す。
    static func indexAfterRemoval(at removedIndex: Int, entries: [Entry]) -> Int? {
        let indices = entries.indices.filter { entries[$0].isFocusable }
        return indices.first { $0 >= removedIndex } ?? indices.last
    }
}

extension DockKeyboardNavigation.Key {
    /// Command、Control、Option を伴う入力は OS やアプリのショートカットに任せる。
    init?(_ press: KeyPress) {
        guard press.modifiers.isDisjoint(with: [.command, .control, .option]) else { return nil }
        switch press.key {
        case .upArrow: self = .arrow(.up)
        case .downArrow: self = .arrow(.down)
        case .leftArrow: self = .arrow(.left)
        case .rightArrow: self = .arrow(.right)
        case .home: self = .home
        case .end: self = .end
        default:
            guard let first = press.characters.first, first.isLetter || first.isNumber else { return nil }
            self = .character(press.characters)
        }
    }
}

enum DockItemMenu {
    enum Kind { case open, reveal, hide, show, hideOthers, quit, forceQuit, remove, keep }

    static func kinds(hasFileURL: Bool, visibility: ApplicationVisibility? = nil, canHideOthers: Bool = false, canQuit: Bool, isPinned: Bool) -> [Kind] {
        let visibilityKinds: [Kind] = visibility.map { [$0 == .hidden ? .show : .hide] } ?? []
        return [.open] + (hasFileURL ? [.reveal] : []) + visibilityKinds + (canHideOthers ? [.hideOthers] : []) + (canQuit ? [.quit, .forceQuit] : []) + [isPinned ? .remove : .keep]
    }
}

extension DockItemMenu.Kind {
    var title: String {
        switch self {
        case .open: "開く"
        case .reveal: "Finder で表示"
        case .hide: "隠す"
        case .show: "表示"
        case .hideOthers: "ほかを隠す"
        case .quit: "終了"
        case .forceQuit: "強制終了…"
        case .remove: "Dock から取り外す"
        case .keep: "Dock に保持"
        }
    }

    var isAccessibilityAction: Bool { self != .open && self != .reveal }
}

struct DockTypeAheadBuffer {
    static let timeout: TimeInterval = 1
    private(set) var text = ""
    private var lastInput: Date?

    mutating func append(_ characters: String, at date: Date) -> String {
        if let lastInput, date.timeIntervalSince(lastInput) > Self.timeout { text = "" }
        text += characters
        lastInput = date
        return text
    }
}
