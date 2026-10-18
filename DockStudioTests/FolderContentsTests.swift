import XCTest
@testable import DockStudio

final class FolderContentsTests: XCTestCase {
    func testItemsPreserveInputOrderAndClassifyEntries() {
        let candidates = [
            candidate("Nested", directory: true),
            candidate("Notes.txt"),
            candidate("Calendar.app", directory: true, application: true, bundleIdentifier: "com.example.Calendar")
        ]

        let items = FolderContentsModel.items(from: candidates)

        XCTAssertEqual(items.map(\.name), ["Nested", "Notes.txt", "Calendar.app"])
        XCTAssertEqual(items.map(\.kind), [.folder, .file, .application])
        XCTAssertEqual(items.last?.bundleIdentifier, "com.example.Calendar")
        XCTAssertEqual(items.map(\.target), candidates.map { $0.url.absoluteString })
    }

    func testApplicationClassificationUsesReaderMetadata() {
        let candidates = [
            candidate("Calendar.app", directory: true, application: true, bundleIdentifier: "com.example.Calendar"),
            candidate("Folder.app", directory: true)
        ]

        let items = FolderContentsModel.items(from: candidates)

        XCTAssertEqual(items.map(\.kind), [.application, .folder])
    }

    func testReaderReturnsAnEmptyListForAnEmptyDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertTrue(try FolderContentsReader.read(at: directory).isEmpty)
    }

    func testReaderClassifiesSymlinkToDirectoryByItsDestination() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let directory = root.appendingPathComponent("Destination", isDirectory: true)
        let link = root.appendingPathComponent("Linked Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory)
        defer { try? FileManager.default.removeItem(at: root) }

        let items = try FolderContentsReader.read(at: root)
        let linkedFolder = items.first { $0.name == "Linked Folder" }

        XCTAssertEqual(linkedFolder?.kind, .folder)
        XCTAssertEqual(linkedFolder?.targetURL?.lastPathComponent, link.lastPathComponent)
    }

    private func candidate(_ name: String, directory: Bool = false, application: Bool = false,
                           bundleIdentifier: String? = nil) -> FolderContentsCandidate {
        FolderContentsCandidate(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            isDirectory: directory,
            isApplication: application,
            bundleIdentifier: bundleIdentifier
        )
    }
}
