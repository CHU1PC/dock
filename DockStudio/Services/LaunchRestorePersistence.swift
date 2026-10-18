import Foundation

struct LaunchRestoreState: Codable, Equatable {
    static let currentVersion = 1
    var version = Self.currentVersion
    var dockVisible: Bool
}

enum LaunchRestorePersistence {
    static func url(besides profiles: URL) -> URL {
        profiles.deletingLastPathComponent().appendingPathComponent("launch-state.json")
    }

    static func load(from url: URL) throws -> LaunchRestoreState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let state = try JSONDecoder().decode(LaunchRestoreState.self, from: Data(contentsOf: url))
        guard state.version == LaunchRestoreState.currentVersion else { throw DockDataError.unsupportedVersion(state.version) }
        return state
    }

    static func save(_ state: LaunchRestoreState, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
}
