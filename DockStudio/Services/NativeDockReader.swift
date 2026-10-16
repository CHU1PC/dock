import Foundation

struct NativeDockReader {
    func readItems() async throws -> [DockItem] {
        let output = try await AsyncProcessRunner().run(executable: URL(fileURLWithPath: "/usr/bin/defaults"),
                                                       arguments: ["export", "com.apple.dock", "-"])
        guard !output.timedOut else { throw DockDataError.invalidData("Reading Apple Dock preferences timed out.") }
        guard output.status == 0 else {
            throw DockDataError.invalidData("Could not read Apple Dock preferences.\n" + String(decoding: output.stderr, as: UTF8.self))
        }
        return try decodeItems(output.stdout)
    }

    func decodeItems(_ data: Data) throws -> [DockItem] {
        let snapshot: Snapshot
        do { snapshot = try PropertyListDecoder().decode(Snapshot.self, from: data) }
        catch { throw DockDataError.invalidData("Apple Dock preferences have an unsupported format.\n\(error.localizedDescription)") }
        return try (snapshot.items ?? []).map { tile in
            if ["spacer-tile", "small-spacer-tile"].contains(tile.type) {
                return DockItem(name: "スペーサー", kind: .spacer)
            }
            guard tile.type == "file-tile", let target = tile.data?.file?.url,
                  let url = URL(string: target), url.isFileURL,
                  url.pathExtension == "app" else {
                throw DockDataError.invalidData("Unsupported Apple Dock item: \(tile.type).")
            }
            return DockItem(name: tile.data?.label ?? url.deletingPathExtension().lastPathComponent,
                            kind: .application, target: url.absoluteString)
        }
    }

    private struct Snapshot: Decodable {
        let items: [Tile]?
        enum CodingKeys: String, CodingKey { case items = "persistent-apps" }
    }
    private struct Tile: Decodable {
        let type: String
        let data: TileData?
        enum CodingKeys: String, CodingKey { case type = "tile-type", data = "tile-data" }
    }
    private struct TileData: Decodable {
        let label: String?
        let file: FileReference?
        enum CodingKeys: String, CodingKey { case label = "file-label", file = "file-data" }
    }
    private struct FileReference: Decodable {
        let url: String
        enum CodingKeys: String, CodingKey { case url = "_CFURLString" }
    }
}
