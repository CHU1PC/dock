import AppKit
import ApplicationServices

protocol QuittableApplication {
    var bundleIdentifier: String? { get }
    var bundleURL: URL? { get }
    var processIdentifier: pid_t { get }
    var isTerminated: Bool { get }
    func terminate() -> Bool
    func activate()
    func forceTerminate() -> Bool
}

extension NSRunningApplication: QuittableApplication {
    func activate() {
        guard let bundleURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration)
    }
}

enum ApplicationQuitActivationPolicy {
    static let delay = Duration.milliseconds(750)

    static func shouldActivate(isTerminated: Bool, promptDetection: QuitPromptDetection) -> Bool {
        guard !isTerminated else { return false }
        return switch promptDetection {
        case .detected, .unavailable: true
        case .notDetected: false
        }
    }
}

enum QuitPromptDetection: Equatable {
    case detected
    case notDetected
    case unavailable
}

protocol QuitPromptDetecting {
    func detection(for application: any QuittableApplication) -> QuitPromptDetection
}

struct AccessibilityQuitPromptDetector: QuitPromptDetecting {
    func detection(for application: any QuittableApplication) -> QuitPromptDetection {
        guard AXIsProcessTrusted() else { return .unavailable }
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return .unavailable }
        return containsSheet(in: appElement, depth: 0)
            || windows.contains(where: { containsSheet(in: $0, depth: 0) })
            ? .detected : .notDetected
    }

    private func containsSheet(in element: AXUIElement, depth: Int) -> Bool {
        guard depth < 8 else { return false }
        var roleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success,
           roleValue as? String == (kAXSheetRole as String) {
            return true
        }
        for attributeName in [kAXChildrenAttribute as CFString, "AXSheets" as CFString] {
            var childrenValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attributeName, &childrenValue) == .success,
                  let children = childrenValue as? [AXUIElement] else { continue }
            if children.contains(where: { containsSheet(in: $0, depth: depth + 1) }) { return true }
        }
        return false
    }
}

enum ApplicationQuitOutcome: Equatable {
    case requested
    case notRunning
    case notQuittable
    case rejected
}

struct ApplicationQuitter {
    var runningApplications: (String) -> [any QuittableApplication]
    var excludedBundleIdentifiers: Set<String>
    var promptDetector: any QuitPromptDetecting = AccessibilityQuitPromptDetector()
    var scheduleActivation: (@escaping @MainActor () -> Void) -> Void = { action in
        Task { @MainActor in
            try? await Task.sleep(for: ApplicationQuitActivationPolicy.delay)
            action()
        }
    }

    static let live = ApplicationQuitter(
        runningApplications: { NSRunningApplication.runningApplications(withBundleIdentifier: $0) },
        excludedBundleIdentifiers: ["com.apple.finder", Bundle.main.bundleIdentifier].compactMap { $0 }.reduce(into: []) { $0.insert($1) })

    func quittableBundleIdentifier(for item: DockItem) -> String? {
        guard item.kind == .application, let identity = item.applicationIdentity,
              identity.hasPrefix("bundle:") else { return nil }
        let identifier = String(identity.dropFirst("bundle:".count))
        return excludedBundleIdentifiers.contains(identifier) ? nil : identifier
    }

    func quit(_ item: DockItem) -> ApplicationQuitOutcome {
        request(item) {
            let application = $0
            guard application.terminate() else { return false }
            scheduleActivation {
                guard ApplicationQuitActivationPolicy.shouldActivate(
                    isTerminated: application.isTerminated,
                    promptDetection: promptDetector.detection(for: application)
                ) else { return }
                application.activate()
            }
            return true
        }
    }

    func forceQuit(_ item: DockItem) -> ApplicationQuitOutcome {
        request(item) { $0.forceTerminate() }
    }

    private func request(_ item: DockItem, _ action: (any QuittableApplication) -> Bool) -> ApplicationQuitOutcome {
        guard let identifier = quittableBundleIdentifier(for: item) else { return .notQuittable }
        let running = runningApplications(identifier).filter { !$0.isTerminated }
        guard !running.isEmpty else { return .notRunning }
        let results = running.map(action)
        return results.contains(true) ? .requested : .rejected
    }
}

enum ForceQuitConfirmation {
    static let informativeText = "未保存の変更は失われます。通常の終了で終わらない場合にだけ使ってください。"
}
