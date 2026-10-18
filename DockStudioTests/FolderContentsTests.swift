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

    func testFanLayoutFitsTheSupportedCountAndRejectsOverflow() {
        let positions = FolderFanLayout.positions(count: 8, width: 256, height: 180)

        XCTAssertEqual(positions.count, 8)
        XCTAssertTrue(positions.allSatisfy { (17...239).contains($0.x) && (17...163).contains($0.y) })
        XCTAssertTrue(FolderFanLayout.positions(count: 9, width: 256, height: 180).isEmpty)
        XCTAssertTrue(FolderFanLayout.positions(count: 0, width: 256, height: 180).isEmpty)
    }

    func testOlderFolderItemDecodesWithDefaultDisplayStyle() throws {
        let data = Data("""
        {"id":"00000000-0000-0000-0000-000000000001","name":"Folder","kind":"folder","target":"file:///tmp/"}
        """.utf8)

        let item = try JSONDecoder().decode(DockItem.self, from: data)

        XCTAssertNil(item.folderContentsDisplayStyle)
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
