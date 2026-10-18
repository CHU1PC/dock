import AppKit

enum OptionClickAction: Equatable {
    case launch
    case hideFrontmost
}

enum OptionClickPolicy {
    static func isOptionOnly(_ flags: NSEvent.ModifierFlags) -> Bool {
        flags.intersection([.command, .control, .shift, .option]) == .option
    }

    static func action(flags: NSEvent.ModifierFlags, targetBundleIdentifier: String?,
                       frontmostBundleIdentifier: String?, targetIsRunning: Bool) -> OptionClickAction {
        guard isOptionOnly(flags), targetIsRunning,
              let target = targetBundleIdentifier, target == frontmostBundleIdentifier else { return .launch }
        return .hideFrontmost
    }

    @MainActor
    static func hideIfFrontmost(applicationAt url: URL, flags: NSEvent.ModifierFlags) -> Bool {
        let identifier = Bundle(url: url)?.bundleIdentifier
        let running = identifier.map { NSRunningApplication.runningApplications(withBundleIdentifier: $0) } ?? []
        let action = action(flags: flags, targetBundleIdentifier: identifier,
                            frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                            targetIsRunning: running.contains { !$0.isTerminated })
        guard action == .hideFrontmost else { return false }
        return running.map { $0.hide() }.contains(true)
    }
}
