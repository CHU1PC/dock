import AppKit

struct EjectableVolumeMetadata {
    let isDirectory: Bool
    let isEjectable: Bool
    let volumeURL: URL?
}

struct VolumeEjector {
    var metadata: (URL) -> EjectableVolumeMetadata? = Self.fileMetadata
    var eject: (URL) throws -> Void = Self.workspaceEject

    func isEjectable(_ item: DockItem) -> Bool {
        guard item.kind == .folder, let url = item.targetURL, url.isFileURL,
              let values = metadata(url), values.isDirectory, values.isEjectable,
              let volumeURL = values.volumeURL else { return false }
        let itemPath = url.standardizedFileURL.resolvingSymlinksInPath().path
        let volumePath = volumeURL.standardizedFileURL.resolvingSymlinksInPath().path
        return itemPath == volumePath && itemPath != "/"
    }

    func ejectVolume(at url: URL) throws {
        try eject(url)
    }

    private static func fileMetadata(_ url: URL) -> EjectableVolumeMetadata? {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .volumeIsEjectableKey, .volumeURLKey]) else {
            return nil
        }
        return EjectableVolumeMetadata(isDirectory: values.isDirectory == true,
                                       isEjectable: values.volumeIsEjectable == true,
                                       volumeURL: values.volume)
    }

    private static func workspaceEject(_ url: URL) throws {
        try NSWorkspace.shared.unmountAndEjectDevice(at: url)
    }
}
