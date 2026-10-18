import AppKit
import ApplicationServices

struct ApplicationDockMenuItem: Equatable, Identifiable {
    let id: String
    let title: String
    let children: [ApplicationDockMenuItem]
}

protocol ApplicationDockMenuProviding {
    func menu(for applicationURL: URL) -> [ApplicationDockMenuItem]?
    func perform(itemID: String, for applicationURL: URL) -> Bool
}

struct ApplicationDockMenuAccess {
    var provider: any ApplicationDockMenuProviding

    static let live = ApplicationDockMenuAccess(provider: AccessibilityApplicationDockMenuProvider())

    func menu(for applicationURL: URL) -> [ApplicationDockMenuItem]? {
        provider.menu(for: applicationURL)
    }

    func perform(itemID: String, for applicationURL: URL) -> Bool {
        provider.perform(itemID: itemID, for: applicationURL)
    }
}

private final class AccessibilityApplicationDockMenuProvider: ApplicationDockMenuProviding {
    private let dockBundleIdentifier = "com.apple.dock"
    private let shownMenuAttribute = "AXShownMenuUIElement" as CFString
    private let showMenuAction = "AXShowMenu" as CFString
    private let cancelAction = "AXCancel" as CFString
    private let pressAction = kAXPressAction as CFString

    func menu(for applicationURL: URL) -> [ApplicationDockMenuItem]? {
        guard let (menu, dockItem) = openMenu(for: applicationURL) else { return nil }
        defer { _ = AXUIElementPerformAction(dockItem, cancelAction) }
        guard let children = children(of: menu),
              let optionsIndex = children.firstIndex(where: { title(of: $0) == "Options" || title(of: $0) == "オプション" }) else {
            return nil
        }
        return children.prefix(optionsIndex).enumerated().flatMap { index, element in
            makeItems(element, path: [index])
        }
    }

    func perform(itemID: String, for applicationURL: URL) -> Bool {
        let indices = itemID.split(separator: ".").compactMap { Int($0) }
        guard !indices.isEmpty, let (menu, dockItem) = openMenu(for: applicationURL) else { return false }
        defer { _ = AXUIElementPerformAction(dockItem, cancelAction) }
        var parent = menu
        var target: AXUIElement?
        for index in indices {
            guard let children = children(of: parent), children.indices.contains(index) else { return false }
            target = children[index]
            parent = target!
        }
        guard let target else { return false }
        return AXUIElementPerformAction(target, pressAction) == .success
    }

    private func openMenu(for applicationURL: URL) -> (AXUIElement, AXUIElement)? {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: dockBundleIdentifier).first else {
            return nil
        }
        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        guard let dockItems = children(of: dockElement),
              let dockItem = dockItems.first(where: { url(of: $0) == applicationURL.standardizedFileURL }),
              AXUIElementPerformAction(dockItem, showMenuAction) == .success else { return nil }
        var menuValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockItem, shownMenuAttribute, &menuValue) == .success,
              let menuValue, CFGetTypeID(menuValue) == AXUIElementGetTypeID() else {
            _ = AXUIElementPerformAction(dockItem, cancelAction)
            return nil
        }
        let menu = unsafeBitCast(menuValue, to: AXUIElement.self)
        return (menu, dockItem)
    }

    private func children(of element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? [AXUIElement]
    }

    private func title(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func url(of element: AXUIElement) -> URL? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &value) == .success else { return nil }
        if let url = value as? URL { return url.standardizedFileURL }
        if let url = value as? NSURL { return (url as URL).standardizedFileURL }
        return nil
    }

    private func makeItems(_ element: AXUIElement, path: [Int]) -> [ApplicationDockMenuItem] {
        let childElements = children(of: element) ?? []
        guard let title = title(of: element), !title.isEmpty else {
            return childElements.enumerated().flatMap { index, child in
                makeItems(child, path: path + [index])
            }
        }
        let childItems = childElements.enumerated().flatMap { index, child in
            makeItems(child, path: path + [index])
        }
        return [ApplicationDockMenuItem(id: path.map(String.init).joined(separator: "."), title: title,
                                        children: childItems)]
    }
}
