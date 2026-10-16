import AppKit
import UniformTypeIdentifiers

struct ItemLaunchPolicy {
    func validate(_ item: DockItem) throws -> URL {
        guard let url = item.targetURL else {
            throw DockDataError.invalidData("This item is unavailable. Choose its application or file again.")
        }
        if item.kind == .link {
            guard let scheme = url.scheme, ["http", "https"].contains(scheme),
                  let host = url.host, !host.isEmpty else {
                throw DockDataError.invalidData("Only HTTP and HTTPS links can be opened.")
            }
            return url
        }
        guard url.isFileURL else { throw DockDataError.invalidData("A local file URL is required.") }
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        let values = try resolved.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
        switch item.kind {
        case .application:
            guard resolved.pathExtension.lowercased() == "app", values.isDirectory == true,
                  let bundle = Bundle(url: resolved), bundle.bundleIdentifier != nil,
                  let executable = bundle.executableURL,
                  FileManager.default.isExecutableFile(atPath: executable.path) else {
                throw DockDataError.invalidData("The selected item is not a valid application bundle.")
            }
        case .folder:
            guard values.isDirectory == true, resolved.pathExtension.lowercased() != "app" else {
                throw DockDataError.invalidData("The selected item is not a folder.")
            }
        case .file:
            let blockedExtensions: Set<String> = ["app", "command", "sh", "bash", "zsh", "py", "rb", "pl", "js", "scpt", "scptd", "applescript", "workflow", "jar", "pkg", "dmg"]
            guard values.isDirectory != true,
                  !FileManager.default.isExecutableFile(atPath: resolved.path),
                  !blockedExtensions.contains(resolved.pathExtension.lowercased()),
                  values.contentType?.conforms(to: .executable) != true,
                  values.contentType?.conforms(to: .script) != true else {
                throw DockDataError.invalidData("Executable files and scripts cannot be opened as document items.")
            }
        default:
            throw DockDataError.invalidData("This item has no launch action.")
        }
        return resolved
    }
}
