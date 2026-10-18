import AppKit

protocol HideableApplication {
    var bundleIdentifier: String? { get }
    var isTerminated: Bool { get }
    var isHidden: Bool { get }
    @discardableResult func hide() -> Bool
    @discardableResult func unhide() -> Bool
}

extension NSRunningApplication: HideableApplication {}

enum ApplicationVisibility: Equatable {
    case visible
    case hidden
}

enum ApplicationHideOutcome: Equatable {
    case hidden
    case shown
    case notRunning
    case notHideable
}

struct ApplicationHider {
    var runningApplications: (String) -> [any HideableApplication]
    var excludedBundleIdentifiers: Set<String>

    static let live = ApplicationHider(
        runningApplications: { NSRunningApplication.runningApplications(withBundleIdentifier: $0) },
        excludedBundleIdentifiers: Set([Bundle.main.bundleIdentifier].compactMap { $0 }))

    func hideableBundleIdentifier(for item: DockItem) -> String? {
        guard item.kind == .application, let identity = item.applicationIdentity,
              identity.hasPrefix("bundle:") else { return nil }
        let identifier = String(identity.dropFirst("bundle:".count))
        return excludedBundleIdentifiers.contains(identifier) ? nil : identifier
    }

    func visibility(of item: DockItem) -> ApplicationVisibility? {
        guard let identifier = hideableBundleIdentifier(for: item) else { return nil }
        let running = runningApplications(identifier).filter { !$0.isTerminated }
        guard !running.isEmpty else { return nil }
        return running.allSatisfy { $0.isHidden } ? .hidden : .visible
    }

    func toggle(_ item: DockItem) -> ApplicationHideOutcome {
        guard hideableBundleIdentifier(for: item) != nil else { return .notHideable }
        guard let current = visibility(of: item), let identifier = hideableBundleIdentifier(for: item) else { return .notRunning }
        let running = runningApplications(identifier).filter { !$0.isTerminated }
        // hide() と unhide() の戻り値は、実際に隠れていても false になることがあるので見ない。
        switch current {
        case .visible:
            running.filter { !$0.isHidden }.forEach { $0.hide() }
            return .hidden
        case .hidden:
            running.forEach { $0.unhide() }
            return .shown
        }
    }
}
