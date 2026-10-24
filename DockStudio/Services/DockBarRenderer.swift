import Foundation

/// Dock バーを Core Animation 版で描くかどうかの切り替え。保存する設定には含めない。
enum DockBarRenderer {
    static let defaultsKey = "dockstudio.useLayerDockBar"
    static let environmentKey = "DOCKSTUDIO_LAYER_DOCK_BAR"

    static func isLayerEnabled(defaults: UserDefaults = .standard,
                               environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        defaults.bool(forKey: defaultsKey) || environment[environmentKey] == "1"
    }

    static func usesLayerBar(enabled: Bool, position: DockPosition) -> Bool {
        enabled && position == .bottom
    }
}
