import AppKit

struct ProfileArchive: Codable {
    var formatVersion = 1
    var profiles: [ArchivedProfile]
    var activeProfileID: UUID
    var settings: DockSettings

    struct ArchivedProfile: Codable {
        var id: UUID
        var name: String
        var items: [ArchivedItem]
    }

    struct ArchivedItem: Codable {
        var name: String
        var kind: DockItemKind
        var bundleIdentifier: String?
        var homeRelativePath: String?
        var webURL: String?
    }

    @MainActor
    init(document: DockDocument, home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        activeProfileID = document.activeProfileID
        settings = document.settings
        let prefix = home.standardizedFileURL.path + "/"
        profiles = document.profiles.map { profile in
            ArchivedProfile(id: profile.id, name: profile.name, items: profile.items.map { item in
                let url = item.targetURL
                var relative: String?
                if [.file, .folder].contains(item.kind), let url,
                   url.standardizedFileURL.path.hasPrefix(prefix) {
                    relative = String(url.standardizedFileURL.path.dropFirst(prefix.count))
                }
                return ArchivedItem(name: item.name, kind: item.kind,
                                    bundleIdentifier: [.application, .applicationList].contains(item.kind)
                                        ? url.flatMap { Bundle(url: $0)?.bundleIdentifier } ?? item.bundleIdentifier : nil,
                                    homeRelativePath: relative,
                                    webURL: item.kind == .link ? item.target : nil)
            })
        }
    }

    @MainActor
    func resolve(home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> DockDocument {
        guard formatVersion == 1 else { throw DockDataError.unsupportedVersion(formatVersion) }
        let resolvedProfiles = try profiles.map { profile in
            DockProfile(id: profile.id, name: profile.name, items: try profile.items.map { item in
                var target: String?
                switch item.kind {
                case .application:
                    target = item.bundleIdentifier.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)?.absoluteString }
                case .file, .folder:
                    if let relative = item.homeRelativePath {
                        let parts = relative.split(separator: "/", omittingEmptySubsequences: false)
                        guard !relative.hasPrefix("/"), !parts.contains(".."), !parts.contains("."),
                              !parts.contains("") else {
                            throw DockDataError.invalidData("An archive contains an invalid relative path.")
                        }
                        target = home.appendingPathComponent(relative).absoluteString
                    }
                case .link: target = item.webURL
                default: break
                }
                return DockItem(name: item.name, kind: item.kind, target: target,
                                bundleIdentifier: item.bundleIdentifier, requiresLaunchConfirmation: true)
            })
        }
        let document = DockDocument(profiles: resolvedProfiles, activeProfileID: activeProfileID, settings: settings)
        try document.validate()
        return document
    }

    @MainActor
    static func decode(_ data: Data) throws -> DockDocument {
        struct Header: Decodable { let formatVersion: Int? }
        let header = try JSONDecoder().decode(Header.self, from: data)
        if header.formatVersion != nil { return try JSONDecoder().decode(ProfileArchive.self, from: data).resolve() }
        var legacy = try ProfilePersistence(fileURL: URL(fileURLWithPath: "/unused")).decode(data)
        for index in legacy.profiles.indices {
            for item in legacy.profiles[index].items.indices {
                legacy.profiles[index].items[item].requiresLaunchConfirmation = true
            }
        }
        return legacy
    }
}

struct PendingProfileImport: Identifiable {
    let id = UUID()
    let document: DockDocument
}
