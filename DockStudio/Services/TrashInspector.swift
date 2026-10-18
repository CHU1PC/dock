import Foundation
import AppKit

enum TrashState: Equatable {
    case empty, hasItems, unknown
}

struct TrashInspector: Sendable {
    let finderItemCount: @Sendable () -> Int?
    let locations: @Sendable () -> [URL]

    init(finderItemCount: @escaping @Sendable () -> Int? = { Self.finderItemCount() },
         locations: @escaping @Sendable () -> [URL] = { TrashInspector.systemLocations() }) {
        self.finderItemCount = finderItemCount
        self.locations = locations
    }

    func state() -> TrashState {
        if let count = finderItemCount() {
            return count == 0 ? .empty : .hasItems
        }

        var unreadable = false
        for url in locations() {
            switch Self.probe(url) {
            case .hasItems: return .hasItems
            case .unreadable: unreadable = true
            case .empty: break
            }
        }
        return unreadable ? .unknown : .empty
    }

    enum Probe: Equatable { case empty, hasItems, unreadable }

    static func state(forFinderItemCount count: Int?) -> TrashState? {
        guard let count, count >= 0 else { return nil }
        return count == 0 ? .empty : .hasItems
    }

    static func finderItemCount() -> Int? {
        let script = NSAppleScript(source: "tell application id \"com.apple.finder\" to count items of trash")
        guard let result = script?.executeAndReturnError(nil), result.descriptorType == typeSInt32 else { return nil }
        let count = Int(result.int32Value)
        return count >= 0 ? count : nil
    }

    static func probe(_ url: URL) -> Probe {
        do {
            let names = try FileManager.default.contentsOfDirectory(atPath: url.path)
            return names.contains { $0 != ".DS_Store" } ? .hasItems : .empty
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain, error.code == NSFileReadNoSuchFileError { return .empty }
            if error.domain == NSPOSIXErrorDomain, error.code == Int(ENOENT) { return .empty }
            return .unreadable
        }
    }

    static func systemLocations() -> [URL] {
        let home = (try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsLocalKey],
                                                            options: [.skipHiddenVolumes]) ?? []
        let others = volumes.filter { $0.path != "/" && (try? $0.resourceValues(forKeys: [.volumeIsLocalKey]).volumeIsLocal) == true }
            .map { $0.appendingPathComponent(".Trashes/\(getuid())") }
        return [home] + others
    }
}
