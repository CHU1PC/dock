import AppKit

enum ItemClickAction: Equatable {
    case open
    case revealInFinder(URL)
    case unavailable(String)
    case ignore
}

struct ItemClickPolicy {
    static func isRevealClick(_ flags: NSEvent.ModifierFlags) -> Bool {
        flags.intersection([.command, .option, .control, .shift]) == [.command]
    }

    static func clickModifiers(event: NSEvent.ModifierFlags?, current: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        event ?? current
    }

    func action(for item: DockItem, revealRequested: Bool, availability: ItemAvailability) -> ItemClickAction {
        guard revealRequested else { return .open }
        switch item.kind {
        case .application, .folder, .file: break
        default: return .ignore
        }
        switch availability {
        case .missing:
            return .unavailable("\(item.name) は見つかりません。参照先が移動または削除された可能性があります。")
        case .volumeNotMounted:
            return .unavailable("\(item.name) があるボリュームが接続されていません。接続してからもう一度開いてください。")
        case .available, .inaccessible: break
        }
        guard let url = item.targetURL, url.isFileURL else { return .ignore }
        return .revealInFinder(url.standardizedFileURL)
    }
}

extension DockStore {
    func clickItem(_ item: DockItem, modifiers: NSEvent.ModifierFlags) {
        let reveal = ItemClickPolicy.isRevealClick(modifiers)
        guard reveal else { openItem(item); return }
        guard !isPreview else { status = "\(item.name) を Finder で表示します"; return }
        let current = ItemAvailabilityChecker().check(item)
        itemAvailability.record(item, current)
        switch ItemClickPolicy().action(for: item, revealRequested: true, availability: current) {
        case .open: openItem(item)
        case .revealInFinder(let url):
            NSWorkspace.shared.activateFileViewerSelecting([url])
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.activate()
        case .unavailable(let message): errorMessage = message
        case .ignore: break
        }
    }
}
