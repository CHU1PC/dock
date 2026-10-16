import Foundation

enum DockItemKind: String, Codable, CaseIterable, Identifiable {
    case application, folder, file, link, spacer, clock, focusTimer

    var id: String { rawValue }
    var title: String {
        switch self {
        case .application: "アプリ"
        case .folder: "フォルダ"
        case .file: "ファイル"
        case .link: "リンク"
        case .spacer: "スペーサー"
        case .clock: "時計"
        case .focusTimer: "集中タイマー"
        }
    }
    var symbol: String {
        switch self {
        case .application: "app.fill"
        case .folder: "folder.fill"
        case .file: "doc.fill"
        case .link: "link"
        case .spacer: "rectangle.split.2x1"
        case .clock: "clock"
        case .focusTimer: "timer"
        }
    }
}

struct DockItem: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var kind: DockItemKind
    var target: String?
    var bundleIdentifier: String?
    var requiresLaunchConfirmation: Bool?

    var targetURL: URL? { target.flatMap(URL.init(string:)) }

    var applicationIdentity: String? {
        guard kind == .application else { return nil }
        if let url = targetURL {
            let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
            if let identifier = Bundle(url: canonical)?.bundleIdentifier { return "bundle:\(identifier)" }
            return "path:\(canonical.path)"
        }
        return bundleIdentifier.map { "bundle:\($0)" }
    }
}

struct DockProfile: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var items: [DockItem]
}

enum DockMode: String, Codable, CaseIterable, Identifiable {
    case native, custom, both
    var id: String { rawValue }
    var title: String {
        switch self {
        case .native: "Apple Dock"
        case .custom: "Custom Dock"
        case .both: "両方"
        }
    }
    var description: String {
        switch self {
        case .native: "Custom Dock を隠し、Apple Dock を使います。"
        case .custom: "独立した Custom Dock を表示します。Apple Dock はシステム設定で調整できます。"
        case .both: "Apple Dock と Custom Dock を一緒に使います。"
        }
    }
}

enum DockPosition: String, Codable, CaseIterable, Identifiable {
    case left, bottom, right
    var id: String { rawValue }
    var title: String {
        switch self {
        case .left: "左"
        case .bottom: "下"
        case .right: "右"
        }
    }
}

struct DockSettings: Codable, Equatable {
    var mode: DockMode = .both
    var position: DockPosition = .bottom
    var iconSize = 52.0
    var autoHide = false
    var showRunningApps = false
    var displayID: UInt32?
}

struct DockDocument: Codable, Equatable {
    var schemaVersion = 1
    var profiles: [DockProfile]
    var activeProfileID: UUID
    var settings = DockSettings()

    func validate() throws {
        guard schemaVersion == 1 else { throw DockDataError.unsupportedVersion(schemaVersion) }
        guard !profiles.isEmpty, profiles.contains(where: { $0.id == activeProfileID }),
              Set(profiles.map(\.id)).count == profiles.count else {
            throw DockDataError.invalidData("Invalid profile identifiers or active profile.")
        }
        guard (40...76).contains(settings.iconSize), settings.iconSize.isFinite else {
            throw DockDataError.invalidData("Invalid icon size.")
        }
        for profile in profiles {
            guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  Set(profile.items.map(\.id)).count == profile.items.count else {
                throw DockDataError.invalidData("Invalid profile name or duplicate item identifiers.")
            }
            for item in profile.items {
                guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw DockDataError.invalidData("Item name must not be empty.")
                }
                switch item.kind {
                case .application, .folder, .file:
                    if item.target == nil { continue }
                    guard let url = item.targetURL, url.isFileURL,
                          url.host == nil || url.host == "" || url.host == "localhost" else {
                        throw DockDataError.invalidData("File items require a file URL.")
                    }
                    if item.kind == .application, url.pathExtension.lowercased() != "app" {
                        throw DockDataError.invalidData("Application items require an app bundle.")
                    }
                case .link:
                    guard let url = item.targetURL, let scheme = url.scheme, ["https", "http"].contains(scheme),
                          let host = url.host, !host.isEmpty else {
                        throw DockDataError.invalidData("Links require an HTTP or HTTPS URL.")
                    }
                case .spacer, .clock, .focusTimer: break
                }
            }
        }
    }
}

enum DockDataError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidData(String)
    case readOnly

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): "Unsupported document version: \(version)."
        case .invalidData(let message): message
        case .readOnly: "The existing configuration could not be loaded. It has been preserved; saving is disabled."
        }
    }
}
