import AppKit

protocol HideableApplication {
    var bundleIdentifier: String? { get }
    var isTerminated: Bool { get }
    var isHidden: Bool { get }
    func hide() -> Bool
    func unhide() -> Bool
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
    case rejected
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
        switch current {
        case .visible:
            let results = running.filter { !$0.isHidden }.map { $0.hide() }
            return results.contains(true) ? .hidden : .rejected
        case .hidden:
            let results = running.map { $0.unhide() }
            return results.contains(true) ? .shown : .rejected
        }
    }
}
