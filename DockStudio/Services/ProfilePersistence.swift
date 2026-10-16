import Foundation

struct ProfilePersistence {
    let fileURL: URL

    var draftsURL: URL { fileURL.appendingPathExtension("drafts.json") }

    static var applicationDefault: ProfilePersistence {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DockStudio", isDirectory: true)
        return ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json"))
    }

    func load() throws -> DockDocument? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try decode(Data(contentsOf: fileURL))
    }

    func save(_ document: DockDocument) throws {
        let data = try encode(document)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    func decode(_ data: Data) throws -> DockDocument {
        let document = try JSONDecoder().decode(DockDocument.self, from: data)
        try document.validate()
        return document
    }

    func encode(_ document: DockDocument) throws -> Data {
        try document.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    func loadDrafts() throws -> [DockProfile] {
        guard FileManager.default.fileExists(atPath: draftsURL.path) else { return [] }
        let recovery = try JSONDecoder().decode(DraftRecovery.self, from: Data(contentsOf: draftsURL))
        guard recovery.version == 1 else { throw DockDataError.unsupportedVersion(recovery.version) }
        guard Set(recovery.profiles.map(\.id)).count == recovery.profiles.count else {
            throw DockDataError.invalidData("Duplicate draft profile identifiers.")
        }
        guard recovery.profiles.allSatisfy({ Set($0.items.map(\.id)).count == $0.items.count }) else {
            throw DockDataError.invalidData("Duplicate draft item identifiers.")
        }
        return recovery.profiles
    }

    func saveDrafts(_ profiles: [DockProfile]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(DraftRecovery(profiles: profiles))
        try data.write(to: draftsURL, options: .atomic)
    }
}

private struct DraftRecovery: Codable {
    var version = 1
    var profiles: [DockProfile]
}
