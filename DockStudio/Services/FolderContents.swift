import AppKit

struct FolderContentsCandidate: Equatable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isApplication: Bool
    let bundleIdentifier: String?
    let dateAdded: Date?
    let dateModified: Date?
    let dateCreated: Date?
}

enum FolderSortOrder: String, Codable, CaseIterable, Identifiable {
    case name
    case dateAdded
    case dateModified
    case dateCreated
    case kind

    var id: String { rawValue }
    var title: String {
        switch self {
        case .name: "名前"
        case .dateAdded: "追加日"
        case .dateModified: "変更日"
        case .dateCreated: "作成日"
        case .kind: "種類"
        }
    }
}

enum FolderContentsModel {
    static func items(from candidates: [FolderContentsCandidate]) -> [DockItem] {
        candidates.map { candidate in
            let kind: DockItemKind = candidate.isApplication ? .application : candidate.isDirectory ? .folder : .file
            return DockItem(name: candidate.name, kind: kind, target: candidate.url.absoluteString,
                            bundleIdentifier: candidate.bundleIdentifier)
        }
    }

    static func sorted(_ candidates: [FolderContentsCandidate], by order: FolderSortOrder) -> [FolderContentsCandidate] {
        candidates.sorted { lhs, rhs in
            switch order {
            case .name:
                return compareNames(lhs, rhs)
            case .dateAdded:
                if compareDates(lhs.dateAdded, rhs.dateAdded) { return true }
                if compareDates(rhs.dateAdded, lhs.dateAdded) { return false }
            case .dateModified:
                if compareDates(lhs.dateModified, rhs.dateModified) { return true }
                if compareDates(rhs.dateModified, lhs.dateModified) { return false }
            case .dateCreated:
                if compareDates(lhs.dateCreated, rhs.dateCreated) { return true }
                if compareDates(rhs.dateCreated, lhs.dateCreated) { return false }
            case .kind:
                let leftKind = kindRank(lhs)
                let rightKind = kindRank(rhs)
                if leftKind != rightKind { return leftKind < rightKind }
            }
            return compareNames(lhs, rhs)
        }
    }

    private static func compareDates(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case let (left?, right?): left < right
        case (_?, nil): true
        default: false
        }
    }

    private static func compareNames(_ lhs: FolderContentsCandidate, _ rhs: FolderContentsCandidate) -> Bool {
        let result = lhs.name.localizedStandardCompare(rhs.name)
        if result != .orderedSame { return result == .orderedAscending }
        return lhs.url.absoluteString < rhs.url.absoluteString
    }

    private static func kindRank(_ candidate: FolderContentsCandidate) -> Int {
        if candidate.isDirectory && !candidate.isApplication { return 0 }
        return candidate.isApplication ? 1 : 2
    }
}

enum FolderFanLayout {
    static let maximumItemCount = 8

    static func positions(count: Int, width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard count > 0, count <= maximumItemCount else { return [] }
        let radius = min(width * 0.42, height * 0.72)
        let center = CGPoint(x: width / 2, y: height - 28)
        let startAngle = 205.0 * .pi / 180
        let endAngle = 335.0 * .pi / 180
        guard count > 1 else {
            return [CGPoint(x: center.x, y: center.y - radius)]
        }
        return (0..<count).map { index in
            let fraction = Double(index) / Double(count - 1)
            let angle = startAngle + (endAngle - startAngle) * fraction
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
    }
}

enum FolderContentsReader {
    static func read(at url: URL, sortOrder: FolderSortOrder = .name,
                     fileManager: FileManager = .default) throws -> [DockItem] {
        let children = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .addedToDirectoryDateKey,
                                         .contentModificationDateKey, .creationDateKey],
            options: []
        )
        let candidates = children.map { child -> FolderContentsCandidate in
            let resolved = child.resolvingSymlinksInPath()
            let values = try? resolved.resourceValues(forKeys: [.isDirectoryKey])
            let isApplication = resolved.pathExtension.lowercased() == "app"
                && values?.isDirectory == true
                && Bundle(url: resolved)?.bundleIdentifier != nil
            return FolderContentsCandidate(
                url: child,
                name: child.lastPathComponent,
                isDirectory: values?.isDirectory == true,
                isApplication: isApplication,
                bundleIdentifier: isApplication ? Bundle(url: resolved)?.bundleIdentifier : nil,
                dateAdded: values?.addedToDirectoryDate,
                dateModified: values?.contentModificationDate,
                dateCreated: values?.creationDate
            )
        }
        return FolderContentsModel.items(from: FolderContentsModel.sorted(candidates, by: sortOrder))
    }
}
