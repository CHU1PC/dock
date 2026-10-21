import XCTest
@testable import DockStudio

final class DuplicateItemPolicyTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func makeApp(_ name: String, identifier: String, in parent: URL? = nil) throws -> URL {
        let app = (parent ?? directory).appendingPathComponent("\(name).app")
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>CFBundleIdentifier</key><string>\(identifier)</string></dict></plist>
        """.write(to: app.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)
        return app
    }

    private func item(_ url: URL, _ kind: DockItemKind) -> DockItem {
        DockItem(name: url.lastPathComponent, kind: kind, target: url.absoluteString)
    }

    private func makeFolder(_ name: String, in parent: URL? = nil) throws -> URL {
        let folder = (parent ?? directory).appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func testSameApplicationTwiceIsDuplicate() throws {
        let app = item(try makeApp("A", identifier: "t.a"), .application)
        let result = DuplicateItemPolicy.split([app], existing: [app])
        XCTAssertTrue(result.accepted.isEmpty)
        XCTAssertEqual(result.duplicates.count, 1)
    }

    func testSameBundleIdentifierInDifferentLocationsIsDuplicate() throws {
        let other = try makeFolder("other")
        let first = item(try makeApp("A", identifier: "t.a"), .application)
        let second = item(try makeApp("A", identifier: "t.a", in: other), .application)
        XCTAssertEqual(DuplicateItemPolicy.split([second], existing: [first]).duplicates.count, 1)
    }

    func testSameFolderTwiceIsDuplicate() throws {
        let folder = item(try makeFolder("F"), .folder)
        let result = DuplicateItemPolicy.split([folder], existing: [folder])
        XCTAssertTrue(result.accepted.isEmpty)
        XCTAssertEqual(result.duplicates.count, 1)
    }

    func testSameNameInDifferentFoldersIsNotDuplicate() throws {
        let one = try makeFolder("one")
        let two = try makeFolder("two")
        let a = one.appendingPathComponent("note.txt")
        let b = two.appendingPathComponent("note.txt")
        try "x".write(to: a, atomically: true, encoding: .utf8)
        try "y".write(to: b, atomically: true, encoding: .utf8)
        let result = DuplicateItemPolicy.split([item(b, .file)], existing: [item(a, .file)])
        XCTAssertEqual(result.accepted.count, 1)
        XCTAssertTrue(result.duplicates.isEmpty)
    }

    func testSymlinkToApplicationIsDuplicate() throws {
        let app = try makeApp("A", identifier: "t.a")
        let link = directory.appendingPathComponent("Link.app")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: app)
        XCTAssertEqual(DuplicateItemPolicy.split([item(link, .application)], existing: [item(app, .application)]).duplicates.count, 1)
    }

    func testSymlinkToFolderIsDuplicate() throws {
        let folder = try makeFolder("F")
        let link = directory.appendingPathComponent("FLink")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)
        XCTAssertEqual(DuplicateItemPolicy.split([item(link, .folder)], existing: [item(folder, .folder)]).duplicates.count, 1)
    }

    func testExistingDuplicatesAreNotRemovedAndDoNotBlockNewItems() throws {
        let folder = item(try makeFolder("F"), .folder)
        let file = directory.appendingPathComponent("n.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)
        let existing = [folder, folder]
        let result = DuplicateItemPolicy.split([item(file, .file)], existing: existing)
        XCTAssertEqual(result.accepted.count, 1)
        XCTAssertEqual(existing.count, 2)
    }

    func testMixedCandidatesSeparateNewFromDuplicate() throws {
        let old = directory.appendingPathComponent("old.txt")
        let new = directory.appendingPathComponent("new.txt")
        try "x".write(to: old, atomically: true, encoding: .utf8)
        try "x".write(to: new, atomically: true, encoding: .utf8)
        let result = DuplicateItemPolicy.split([item(old, .file), item(new, .file)], existing: [item(old, .file)])
        XCTAssertEqual(result.accepted.map(\.name), ["new.txt"])
        XCTAssertEqual(result.duplicates.map(\.name), ["old.txt"])
    }

    func testSpacersAndLinksAreNeverDuplicates() {
        let spacer = DockItem(name: "Spacer", kind: .spacer, target: nil)
        XCTAssertEqual(DuplicateItemPolicy.split([spacer, spacer], existing: [spacer]).accepted.count, 2)
    }
}
