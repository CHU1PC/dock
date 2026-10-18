import AppKit
import ApplicationServices

struct ApplicationWindow: Equatable, Identifiable {
    let id: String
    let title: String
    let isMinimized: Bool
}

enum ApplicationWindowListing: Equatable {
    case windows([ApplicationWindow])
    case applicationNotRunning
    case accessibilityPermissionDenied
    case failed
}

protocol ApplicationWindowProviding {
    func windows(for bundleIdentifier: String) -> ApplicationWindowListing
    func activateWindow(id: String, for bundleIdentifier: String) -> Bool
}

struct ApplicationWindowAccess {
    var provider: any ApplicationWindowProviding

    static let live = ApplicationWindowAccess(provider: AccessibilityApplicationWindowProvider())

    func windows(for bundleIdentifier: String) -> ApplicationWindowListing {
        provider.windows(for: bundleIdentifier)
    }

    func activate(windowID: String, for bundleIdentifier: String) -> Bool {
        provider.activateWindow(id: windowID, for: bundleIdentifier)
    }
}

private final class AccessibilityApplicationWindowProvider: ApplicationWindowProviding {
    private var windowElements: [String: (bundleIdentifier: String, element: AXUIElement)] = [:]

    func windows(for bundleIdentifier: String) -> ApplicationWindowListing {
        let applications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { !$0.isTerminated }
        guard let application = applications.first else { return .applicationNotRunning }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return .accessibilityPermissionDenied }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let elements = value as? [AXUIElement] else { return .failed }

        windowElements = windowElements.filter { $0.value.bundleIdentifier != bundleIdentifier }
        let windows = elements.map { element -> ApplicationWindow in
            var titleValue: CFTypeRef?
            let title = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue) == .success
                ? (titleValue as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "名称のないウィンドウ"
                : "名称のないウィンドウ"
            var minimizedValue: CFTypeRef?
            let isMinimized = AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &minimizedValue) == .success
                && (minimizedValue as? Bool ?? false)
            let id = UUID().uuidString
            windowElements[id] = (bundleIdentifier, element)
            return ApplicationWindow(id: id, title: title, isMinimized: isMinimized)
        }
        return .windows(windows)
    }

    func activateWindow(id: String, for bundleIdentifier: String) -> Bool {
        guard let stored = windowElements[id], stored.bundleIdentifier == bundleIdentifier,
              let application = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
                .first(where: { !$0.isTerminated }) else { return false }

        var minimizedValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(stored.element, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
           minimizedValue as? Bool == true {
            guard AXUIElementSetAttributeValue(stored.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success else {
                return false
            }
        }
        _ = application.activate(options: [.activateIgnoringOtherApps])
        return AXUIElementPerformAction(stored.element, kAXRaiseAction as CFString) == .success
    }
}

extension DockStore {
    func applicationWindowListing(for item: DockItem) -> ApplicationWindowListing {
        guard item.kind == .application, let identifier = item.applicationIdentity,
              identifier.hasPrefix("bundle:") else { return .applicationNotRunning }
        return applicationWindowAccess.windows(for: String(identifier.dropFirst("bundle:".count)))
    }

    func activateApplicationWindow(_ windowID: String, for item: DockItem) {
        guard item.kind == .application, let identity = item.applicationIdentity,
              identity.hasPrefix("bundle:") else { return }
        let bundleIdentifier = String(identity.dropFirst("bundle:".count))
        guard applicationWindowAccess.activate(windowID: windowID, for: bundleIdentifier) else {
            errorMessage = "\(item.name) のウィンドウを前面にできませんでした。"
            return
        }
        status = "\(item.name) のウィンドウを前面にしました"
    }
}
