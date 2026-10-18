import AppKit

struct FolderContentsCandidate: Equatable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isApplication: Bool
    let bundleIdentifier: String?
}

enum FolderContentsModel {
    static func items(from candidates: [FolderContentsCandidate]) -> [DockItem] {
        candidates.map { candidate in
            let kind: DockItemKind = candidate.isApplication ? .application : candidate.isDirectory ? .folder : .file
            return DockItem(name: candidate.name, kind: kind, target: candidate.url.absoluteString,
                            bundleIdentifier: candidate.bundleIdentifier)
        }
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
    static func read(at url: URL, fileManager: FileManager = .default) throws -> [DockItem] {
        let children = try fileManager.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: []
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
                bundleIdentifier: isApplication ? Bundle(url: resolved)?.bundleIdentifier : nil
            )
        }
        return FolderContentsModel.items(from: candidates)
    }
}
