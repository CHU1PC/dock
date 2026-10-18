import Foundation
import SwiftUI

enum DockKeyboardNavigation {
    enum Arrow { case up, down, left, right }
    enum Key: Equatable { case arrow(Arrow), reorder(Arrow), home, end, character(String) }
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

    /// Option+矢印で項目を動かす順方向を返す。Dock の並びと直交する方向は扱わない。
    static func reorderOffset(for arrow: Arrow, position: DockPosition) -> Int? {
        switch (position, arrow) {
        case (.bottom, .left), (.left, .up), (.right, .up): -1
        case (.bottom, .right), (.left, .down), (.right, .down): 1
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
    private static let semanticModifiers: EventModifiers = [.command, .option, .control, .shift]

    /// Command、Control、Option、Shift を伴う入力は OS やアプリのショートカットに任せる。
    init?(_ press: KeyPress) {
        self.init(key: press.key, characters: press.characters, modifiers: press.modifiers)
    }

    init?(key: KeyEquivalent, characters: String, modifiers: EventModifiers) {
        let semanticModifiers = modifiers.intersection(Self.semanticModifiers)
        if semanticModifiers == [.option] {
            switch key {
            case .upArrow: self = .reorder(.up)
            case .downArrow: self = .reorder(.down)
            case .leftArrow: self = .reorder(.left)
            case .rightArrow: self = .reorder(.right)
            default: return nil
            }
            return
        }
        guard semanticModifiers.isEmpty else { return nil }
        switch key {
        case .upArrow: self = .arrow(.up)
        case .downArrow: self = .arrow(.down)
        case .leftArrow: self = .arrow(.left)
        case .rightArrow: self = .arrow(.right)
        case .home: self = .home
        case .end: self = .end
        default:
            guard let first = characters.first, first.isLetter || first.isNumber else { return nil }
            self = .character(characters)
        }
    }
}

enum DockItemMenu {
    enum Kind { case open, reveal, spacesAssignmentGuide, openLoginItemsSettings, hide, show, hideOthers, quit, forceQuit, remove, keep, finderNewWindow, finderShowAllWindows, setFolderIcon, setStackIcon }

    static let spacesAssignmentGuideMessage = "標準 Dock のアプリアイコンを Control キーを押しながらクリックし、「オプション」>「割り当て先」から設定してください。Spaces が2つ以上あると選択肢が表示されます。標準 Dock にアプリアイコンがない場合は、先にそのアプリを標準 Dock に追加してください。"

    static func kinds(hasFileURL: Bool, visibility: ApplicationVisibility? = nil, canHideOthers: Bool = false,
                      canQuit: Bool, isPinned: Bool, isFinder: Bool = false, finderEntryEnabled: Bool = false,
                      folderDisplayStyle: FolderDisplayStyle? = nil, isApplication: Bool = false) -> [Kind] {
        let applicationKinds: [Kind] = isApplication ? [.openLoginItemsSettings, .spacesAssignmentGuide] : []
        if isFinder {
            let actions: [Kind] = [.open, .finderNewWindow, .finderShowAllWindows] + applicationKinds
            guard !finderEntryEnabled else { return actions }
            return actions + (hasFileURL ? [.reveal] : []) + [isPinned ? .remove : .keep]
        }
        let visibilityKinds: [Kind] = visibility.map { [$0 == .hidden ? .show : .hide] } ?? []
        let folderKinds: [Kind] = switch folderDisplayStyle {
        case .folder: [.setStackIcon]
        case .stack: [.setFolderIcon]
        case nil: []
        }
        return [.open] + (hasFileURL ? [.reveal] : []) + applicationKinds + visibilityKinds + folderKinds
            + (canHideOthers ? [.hideOthers] : []) + (canQuit ? [.quit, .forceQuit] : []) + [isPinned ? .remove : .keep]
    }
}

extension DockItemMenu.Kind {
    var title: String {
        switch self {
        case .open: "開く"
        case .reveal: "Finder で表示"
        case .spacesAssignmentGuide: "Spaces への割り当て方法"
        case .openLoginItemsSettings: "システム設定のログイン項目を開く"
        case .hide: "隠す"
        case .show: "表示"
        case .hideOthers: "ほかを隠す"
        case .quit: "終了"
        case .forceQuit: "強制終了…"
        case .remove: "Dock から取り外す"
        case .keep: "Dock に保持"
        case .finderNewWindow: "新規 Finder ウインドウ"
        case .finderShowAllWindows: "Finder を表示"
        case .setFolderIcon: "フォルダとして表示"
        case .setStackIcon: "Stack として表示"
        }
    }

    var isAccessibilityAction: Bool { self != .open && self != .reveal && self != .openLoginItemsSettings }
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
