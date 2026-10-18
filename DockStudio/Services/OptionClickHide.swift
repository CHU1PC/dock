import AppKit

enum OptionClickAction: Equatable {
    case launch
    case hideTarget
    case activateAndHide(previous: String)
}

enum OptionClickPolicy {
    static func isOptionOnly(_ flags: NSEvent.ModifierFlags) -> Bool {
        flags.intersection([.command, .control, .shift, .option]) == .option
    }

    static func action(flags: NSEvent.ModifierFlags, targetBundleIdentifier: String?,
                       frontmostBundleIdentifier: String?, ownBundleIdentifier: String?,
                       targetIsRunning: Bool) -> OptionClickAction {
        guard isOptionOnly(flags), targetIsRunning, let target = targetBundleIdentifier else { return .launch }
        guard let front = frontmostBundleIdentifier else { return .launch }
        if front == target { return .hideTarget }
        if front == ownBundleIdentifier { return .launch }
        return .activateAndHide(previous: front)
    }

    @MainActor
    static func perform(applicationAt url: URL, flags: NSEvent.ModifierFlags) -> Bool {
        let identifier = Bundle(url: url)?.bundleIdentifier
        let running = identifier.map { NSRunningApplication.runningApplications(withBundleIdentifier: $0) } ?? []
        let action = action(flags: flags, targetBundleIdentifier: identifier,
                            frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                            ownBundleIdentifier: Bundle.main.bundleIdentifier,
                            targetIsRunning: running.contains { !$0.isTerminated })
        switch action {
        case .launch:
            return false
        case .hideTarget:
            return running.map { $0.hide() }.contains(true)
        case .activateAndHide(let previous):
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            NSRunningApplication.runningApplications(withBundleIdentifier: previous).forEach { $0.hide() }
            return true
        }
    }
}
