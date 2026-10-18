import AppKit

enum ApplicationListEntry {
    static func item(osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
                     resolve: (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }) -> DockItem? {
        let entry: (name: String, bundleIdentifier: String)
        switch osMajorVersion {
        case 15:
            entry = ("Launchpad", "com.apple.launchpad.launcher")
        case 26...:
            entry = ("アプリ一覧", "com.apple.apps.launcher")
        default:
            return nil
        }
        guard resolve(entry.bundleIdentifier) != nil else { return nil }
        return DockItem(name: entry.name, kind: .applicationList, bundleIdentifier: entry.bundleIdentifier)
    }

    static func currentItem(for item: DockItem,
                            osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
                            resolve: (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }) -> DockItem? {
        guard item.kind == .applicationList,
              var resolvedItem = self.item(osMajorVersion: osMajorVersion, resolve: resolve) else { return nil }
        resolvedItem.id = item.id
        return resolvedItem
    }
}
