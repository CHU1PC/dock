import Foundation

enum DockSpringLoading {
    enum Action: Equatable {
        case openFolder
    }

    static let hoverDelay: TimeInterval = 1

    static func action(for kind: DockItemKind, elapsed: TimeInterval,
                       delay: TimeInterval = hoverDelay, enabled: Bool) -> Action? {
        guard enabled, kind == .folder, elapsed >= delay else { return nil }
        return .openFolder
    }
}

enum DockSpringLoadingPreferences {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "com.apple.springing.enabled") as? Bool ?? true
    }
}
