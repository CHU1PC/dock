import Foundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import OSLog

enum DockAppearanceWriteError: LocalizedError {
    case busy, changed
    var errorDescription: String? {
        switch self {
        case .busy: "Another application is saving the appearance configuration. Reload it before saving."
        case .changed: "The appearance configuration changed in another application. Reload it before saving."
        }
    }
}

enum DockAppearancePersistence {
    static func save(_ appearance: DockAppearance, to url: URL, expected: Data?) throws -> Data {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let lockURL = url.appendingPathExtension("lock")
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            throw DockAppearanceWriteError.busy
        }
        defer { flock(descriptor, LOCK_UN) }
        let current = FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
        guard current == expected else {
            throw DockAppearanceWriteError.changed
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(appearance)
        try data.write(to: url, options: .atomic)
        return data
    }
}

enum DockBackgroundAssets {
    static func importImage(_ sourceURL: URL, directory: URL?) throws -> String {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048
              ] as CFDictionary) else {
            throw DockDataError.invalidData("Unable to decode the selected background image.")
        }
        guard let directory else { return sourceURL.path }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw DockDataError.invalidData("Unable to encode the selected background image.")
        }
        CGImageDestinationAddImage(destination, thumbnail, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw DockDataError.invalidData("Unable to finalize the selected background image.")
        }
        let images = directory.appendingPathComponent("backgrounds", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        let target = images.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        try (data as Data).write(to: target, options: .atomic)
        return target.path
    }

    static func removeManagedImage(_ path: String?, directory: URL?) {
        guard let path, let directory else { return }
        let file = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let images = directory.appendingPathComponent("backgrounds", isDirectory: true).resolvingSymlinksInPath()
        guard file.deletingLastPathComponent() == images, file.pathExtension == "png",
              UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil else { return }
        do { try FileManager.default.removeItem(at: file) }
        catch { Logger(subsystem: "app.dockstudio.preview", category: "background").error("Unable to remove an unused managed background image") }
    }
}
