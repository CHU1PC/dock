import AppKit

enum DockClickAction: Equatable {
    case open
    case hideOthers

    static func resolve(modifiers: NSEvent.ModifierFlags) -> DockClickAction {
        let relevant = modifiers.intersection([.command, .option, .shift, .control])
        return relevant == [.command, .option] ? .hideOthers : .open
    }
}

protocol HideableApplication {
    var bundleIdentifier: String? { get }
    var processIdentifier: pid_t { get }
    var isRegularApplication: Bool { get }
    var isTerminated: Bool { get }
    var isHidden: Bool { get }
    func activateApplication() -> Bool
    func hideApplication() -> Bool
}

extension NSRunningApplication: HideableApplication {
    var isRegularApplication: Bool { activationPolicy == .regular }
    func activateApplication() -> Bool { activate() }
    func hideApplication() -> Bool { hide() }
}

enum ApplicationHideOutcome: Equatable {
    case hidOthers(Int)
    case notRunning
    case notHideable
    case rejected
}

struct ApplicationHider {
    var runningApplications: () -> [any HideableApplication]
    var ownProcessIdentifier: pid_t

    static let live = ApplicationHider(
        runningApplications: { NSWorkspace.shared.runningApplications },
        ownProcessIdentifier: ProcessInfo.processInfo.processIdentifier)

    func targetBundleIdentifier(for item: DockItem) -> String? {
        guard item.kind == .application, let identity = item.applicationIdentity,
              identity.hasPrefix("bundle:") else { return nil }
        return String(identity.dropFirst("bundle:".count))
    }

    func hideOthers(of item: DockItem) -> ApplicationHideOutcome {
        guard let identifier = targetBundleIdentifier(for: item) else { return .notHideable }
        let all = runningApplications().filter { !$0.isTerminated }
        let targets = all.filter { $0.bundleIdentifier == identifier }
        guard !targets.isEmpty else { return .notRunning }
        guard targets.map({ $0.activateApplication() }).contains(true) else { return .rejected }
        let others = all.filter {
            $0.isRegularApplication && $0.bundleIdentifier != identifier
                && $0.processIdentifier != ownProcessIdentifier && !$0.isHidden
        }
        for app in others { _ = app.hideApplication() }
        return .hidOthers(others.count)
    }
}
