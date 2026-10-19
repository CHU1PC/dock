import AppKit
import ApplicationServices

enum ApplicationExposeResult: Equatable {
    case opened
    case accessibilityPermissionDenied
    case failed
}

protocol ApplicationExposing {
    var isAccessibilityTrusted: Bool { get }
    func showAllWindows(for applicationURL: URL) -> ApplicationExposeResult
}

struct ApplicationExposeAccess {
    var provider: any ApplicationExposing

    static let live = ApplicationExposeAccess(provider: AccessibilityApplicationExposer())

    var isAccessibilityTrusted: Bool { provider.isAccessibilityTrusted }

    func showAllWindows(for applicationURL: URL) -> ApplicationExposeResult {
        provider.showAllWindows(for: applicationURL)
    }
}

enum StandardDockExposeMenu {
    static func acceptedTitles(languageCode: String) -> Set<String> {
        switch languageCode {
        case "en": ["Show All Windows"]
        case "ja": ["すべてのウインドウを表示", "すべてのウィンドウを表示", "全てのウインドウを表示"]
        default: []
        }
    }

    static func matches(title: String, languageCode: String) -> Bool {
        acceptedTitles(languageCode: languageCode).contains(title)
    }
}

enum ApplicationExposeMatcher {
    static func matches(
        targetURL: URL,
        targetBundleIdentifier: String?,
        targetTitle: String,
        dockURL: URL?,
        dockBundleIdentifier: String?,
        dockTitle: String?
    ) -> Bool {
        if let targetBundleIdentifier, let dockBundleIdentifier {
            return targetBundleIdentifier == dockBundleIdentifier
        }

        if let dockURL,
           normalizedPath(targetURL.path) == normalizedPath(dockURL.path) {
            return true
        }

        guard let dockTitle else { return false }
        return normalizedTitle(targetTitle) == normalizedTitle(dockTitle)
    }

    static func normalizedPath(_ path: String) -> String {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        let cryptexPrefix = "/System/Volumes/Preboot/Cryptexes/App/System/Applications/"
        if standardized.hasPrefix(cryptexPrefix) {
            return "/System/Applications/" + String(standardized.dropFirst(cryptexPrefix.count))
        }

        let dataApplicationsPrefix = "/System/Volumes/Data/Applications/"
        if standardized.hasPrefix(dataApplicationsPrefix) {
            return "/Applications/" + String(standardized.dropFirst(dataApplicationsPrefix.count))
        }
        return standardized
    }

    private static func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private final class AccessibilityApplicationExposer: ApplicationExposing {
    var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    func showAllWindows(for applicationURL: URL) -> ApplicationExposeResult {
        guard isAccessibilityTrusted else { return .accessibilityPermissionDenied }
        guard let dock = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.dock" && !$0.isTerminated
        }) else { return .failed }

        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        let targetBundle = Bundle(url: applicationURL)
        let targetBundleIdentifier = targetBundle?.bundleIdentifier
        let targetTitle = targetBundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? applicationURL.deletingPathExtension().lastPathComponent
        guard let item = findApplicationItem(
            in: dockElement,
            matching: applicationURL,
            bundleIdentifier: targetBundleIdentifier,
            title: targetTitle,
            depth: 0
        ) else {
            return .failed
        }
        _ = AXUIElementPerformAction(item, kAXShowMenuAction as CFString)

        guard let menuValue = attribute(kAXShownMenuUIElementAttribute as CFString, of: item) else {
            cancelMenu(on: item)
            return .failed
        }
        let menu = menuValue as! AXUIElement
        guard let menuItem = findShowAllWindowsItem(in: menu, depth: 0) else {
            cancelMenu(on: item)
            return .failed
        }
        let pressResult = AXUIElementPerformAction(menuItem, kAXPressAction as CFString)
        if pressResult == .success { return .opened }
        cancelMenu(on: item)
        return .failed
    }

    private func findApplicationItem(
        in element: AXUIElement,
        matching applicationURL: URL,
        bundleIdentifier: String?,
        title: String,
        depth: Int
    ) -> AXUIElement? {
        guard depth < 5 else { return nil }
        let dockURL = attribute(kAXURLAttribute as CFString, of: element) as? URL
        let dockTitle = stringAttribute(kAXTitleAttribute as CFString, of: element)
        if stringAttribute(kAXSubroleAttribute as CFString, of: element) == (kAXApplicationDockItemSubrole as String),
           ApplicationExposeMatcher.matches(
               targetURL: applicationURL,
               targetBundleIdentifier: bundleIdentifier,
               targetTitle: title,
               dockURL: dockURL,
               dockBundleIdentifier: dockURL.flatMap { Bundle(url: $0)?.bundleIdentifier },
               dockTitle: dockTitle
           ) {
            return element
        }
        return children(of: element).lazy.compactMap {
            self.findApplicationItem(
                in: $0,
                matching: applicationURL,
                bundleIdentifier: bundleIdentifier,
                title: title,
                depth: depth + 1
            )
        }.first
    }

    private func findShowAllWindowsItem(in element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth < 5 else { return nil }
        let languageCode = Locale.current.language.languageCode?.identifier ?? ""
        if stringAttribute(kAXRoleAttribute as CFString, of: element) == (kAXMenuItemRole as String),
           let title = stringAttribute(kAXTitleAttribute as CFString, of: element),
           StandardDockExposeMenu.matches(title: title, languageCode: languageCode) {
            return element
        }
        return children(of: element).lazy.compactMap {
            self.findShowAllWindowsItem(in: $0, depth: depth + 1)
        }.first
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        (attribute(kAXChildrenAttribute as CFString, of: element) as? [AXUIElement]) ?? []
    }

    private func stringAttribute(_ name: CFString, of element: AXUIElement) -> String? {
        attribute(name, of: element) as? String
    }

    private func attribute(_ name: CFString, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value
    }

    private func cancelMenu(on item: AXUIElement) {
        _ = AXUIElementPerformAction(item, kAXCancelAction as CFString)
    }
}

extension DockStore {
    func canShowAllWindows(for item: DockItem) -> Bool {
        guard item.kind == .application, let url = item.targetURL, url.isFileURL,
              applicationExposeAccess.isAccessibilityTrusted else { return false }
        return !failedApplicationExposePaths.contains(normalizedExposePath(url))
    }

    func showAllWindows(for item: DockItem) {
        guard item.kind == .application, let url = item.targetURL, url.isFileURL else { return }
        switch applicationExposeAccess.showAllWindows(for: url) {
        case .opened:
            status = "\(item.name) の全ウィンドウを表示しました"
        case .accessibilityPermissionDenied:
            errorMessage = "アクセシビリティの許可が必要です。システム設定の「プライバシーとセキュリティ」から Dock Studio を許可してください。"
        case .failed:
            failedApplicationExposePaths.insert(normalizedExposePath(url))
            errorMessage = "標準 Dock の「全ウィンドウを表示」を実行できませんでした。この項目は安全のため無効にしました。"
        }
    }

    func showAllWindowsActionTitle(for item: DockItem) -> String {
        if !applicationExposeAccess.isAccessibilityTrusted {
            return "全ウィンドウを表示（アクセシビリティの許可が必要）"
        }
        if let url = item.targetURL, failedApplicationExposePaths.contains(normalizedExposePath(url)) {
            return "全ウィンドウを表示（標準 Dock を操作できません）"
        }
        return DockItemMenu.Kind.showAllWindows.title
    }

    private func normalizedExposePath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
