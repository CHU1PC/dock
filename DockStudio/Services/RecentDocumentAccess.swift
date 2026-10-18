import AppKit
import ApplicationServices

struct RecentDocument: Equatable, Identifiable {
    let id: String
    let title: String
}

protocol RecentDocumentProviding {
    func documents(for applicationURL: URL) -> [RecentDocument]
    func open(documentID: String, for applicationURL: URL) -> Bool
}

struct RecentDocumentAccess {
    var provider: any RecentDocumentProviding

    static let live = RecentDocumentAccess(provider: AccessibilityRecentDocumentProvider())

    func documents(for item: DockItem) -> [RecentDocument] {
        guard item.kind == .application, let url = item.targetURL, url.isFileURL else { return [] }
        return provider.documents(for: url)
    }

    func open(documentID: String, for item: DockItem) -> Bool {
        guard item.kind == .application, let url = item.targetURL, url.isFileURL else { return false }
        return provider.open(documentID: documentID, for: url)
    }
}

private final class AccessibilityRecentDocumentProvider: RecentDocumentProviding {
    func documents(for applicationURL: URL) -> [RecentDocument] {
        guard AXIsProcessTrusted(), let menu = recentMenu(for: applicationURL) else { return [] }
        defer { cancel(menu) }
        return children(of: menu).compactMap { element -> RecentDocument? in
            guard let title = stringAttribute(kAXTitleAttribute as CFString, of: element),
                  let url = urlAttribute(of: element), url.isFileURL else { return nil }
            let id = url.standardizedFileURL.absoluteString
            return RecentDocument(id: id, title: title)
        }
    }

    func open(documentID: String, for applicationURL: URL) -> Bool {
        guard AXIsProcessTrusted(), let menu = recentMenu(for: applicationURL) else { return false }
        defer { cancel(menu) }
        guard let entry = children(of: menu).first(where: {
            urlAttribute(of: $0)?.standardizedFileURL.absoluteString == documentID
        }), urlAttribute(of: entry)?.isFileURL == true else { return false }
        return AXUIElementPerformAction(entry, kAXPressAction as CFString) == .success
    }

    private func recentMenu(for applicationURL: URL) -> AXUIElement? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
              let dockItem = descendants(of: AXUIElementCreateApplication(dock.processIdentifier), depth: 0)
                .first(where: { urlAttribute(of: $0).map { sameFile($0, applicationURL) } == true }),
              AXUIElementPerformAction(dockItem, kAXShowMenuAction as CFString) == .success,
              let recentItem = descendants(of: dockItem, depth: 0).first(where: isShowRecents),
              AXUIElementPerformAction(recentItem, kAXShowMenuAction as CFString) == .success else { return nil }
        return recentItem
    }

    private func descendants(of element: AXUIElement, depth: Int) -> [AXUIElement] {
        guard depth < 8 else { return [] }
        let children = children(of: element)
        return children + children.flatMap { descendants(of: $0, depth: depth + 1) }
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private func isShowRecents(_ element: AXUIElement) -> Bool {
        guard let title = stringAttribute(kAXTitleAttribute as CFString, of: element)?.lowercased() else { return false }
        return title == "show recents" || title == "最近使った項目" || title == "最近使った書類"
    }

    private func stringAttribute(_ attribute: CFString, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private func urlAttribute(of element: AXUIElement) -> URL? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &value) == .success else { return nil }
        if let url = value as? URL { return url }
        if let url = value as? NSURL { return url as URL }
        if let string = value as? String { return URL(string: string) }
        return nil
    }

    private func sameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.resolvingSymlinksInPath().path == rhs.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func cancel(_ element: AXUIElement) {
        _ = AXUIElementPerformAction(element, kAXCancelAction as CFString)
    }
}

extension DockStore {
    func recentDocuments(for item: DockItem) -> [RecentDocument] {
        recentDocumentAccess.documents(for: item)
    }

    func openRecentDocument(_ documentID: String, for item: DockItem) {
        guard recentDocumentAccess.open(documentID: documentID, for: item) else {
            errorMessage = "最近使った書類を開けませんでした。"
            return
        }
        status = "最近使った書類を開きました"
    }
}
