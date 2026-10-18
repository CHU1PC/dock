import AppKit

enum FinderDockEntry {
    static let bundleIdentifier = "com.apple.finder"
    private static let identifier = UUID(uuidString: "00000000-0000-0000-0000-000000000057")!

    static func isFinder(_ item: DockItem) -> Bool {
        item.kind == .application && (item.bundleIdentifier == bundleIdentifier ||
            item.applicationIdentity == "bundle:\(bundleIdentifier)")
    }

    static func item() -> DockItem {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        return DockItem(id: identifier, name: "Finder", kind: .application,
                        target: url.absoluteString, bundleIdentifier: bundleIdentifier)
    }

    static func displayedItems(_ items: [DockItem], enabled: Bool) -> [DockItem] {
        guard enabled else { return items }
        let finder = items.first(where: isFinder) ?? item()
        return [finder] + items.filter { !isFinder($0) }
    }

    @MainActor
    static func openNewWindow() {
        NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true))
    }

    @MainActor
    static func showFinder() {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            openNewWindow()
            return
        }
        finder.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
    }
}
