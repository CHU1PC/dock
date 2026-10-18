import AppKit
import ApplicationServices

struct NotificationBadgeSnapshot: Sendable {
    let badgesByPath: [String: String]
    let hasAccessibilityPermission: Bool

    static func key(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    static func badge(for item: DockItem, in badgesByPath: [String: String]) -> String? {
        guard item.kind == .application, let url = item.targetURL, url.isFileURL else { return nil }
        return badgesByPath[key(for: url)]
    }
}

struct NotificationBadgeReader {
    private static let statusLabel = "AXStatusLabel" as CFString
    private static let urlAttribute = "AXURL" as CFString
    private static let childrenAttribute = kAXChildrenAttribute as CFString

    func read() -> NotificationBadgeSnapshot {
        guard AXIsProcessTrusted() else {
            return NotificationBadgeSnapshot(badgesByPath: [:], hasAccessibilityPermission: false)
        }
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return NotificationBadgeSnapshot(badgesByPath: [:], hasAccessibilityPermission: true)
        }
        let root = AXUIElementCreateApplication(dock.processIdentifier)
        var badges: [String: String] = [:]
        readChildren(of: root, depth: 0, into: &badges)
        return NotificationBadgeSnapshot(badgesByPath: badges, hasAccessibilityPermission: true)
    }

    private func readChildren(of element: AXUIElement, depth: Int, into badges: inout [String: String]) {
        guard depth < 8 else { return }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, Self.childrenAttribute, &value) == .success,
              let children = value as? [AXUIElement] else { return }
        for child in children {
            if let url = fileURL(attribute: Self.urlAttribute, from: child),
               let label = string(attribute: Self.statusLabel, from: child), !label.isEmpty {
                badges[NotificationBadgeSnapshot.key(for: url)] = label
            }
            readChildren(of: child, depth: depth + 1, into: &badges)
        }
    }

    private func fileURL(attribute: CFString, from element: AXUIElement) -> URL? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        if let url = value as? URL, url.isFileURL { return url }
        if let string = value as? String, let url = URL(string: string), url.isFileURL { return url }
        return nil
    }

    private func string(attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }
}
