import Foundation

struct LaunchRestoreState: Codable, Equatable {
    var dockVisible: Bool
}

enum LaunchRestorePersistence {
    static func url(besides profiles: URL) -> URL {
        profiles.deletingLastPathComponent().appendingPathComponent("launch-state.json")
    }

    static func load(from url: URL) throws -> LaunchRestoreState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(LaunchRestoreState.self, from: Data(contentsOf: url))
    }

    static func save(_ state: LaunchRestoreState, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
}
