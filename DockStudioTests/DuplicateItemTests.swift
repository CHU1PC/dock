import XCTest
@testable import DockStudio

@MainActor
final class DuplicateItemTests: XCTestCase {
    private var directory: URL!
    private var persistence: ProfilePersistence!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        persistence = ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json"))
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func makeApp(_ name: String, identifier: String) throws -> URL {
        let app = directory.appendingPathComponent("\(name).app")
        let macOS = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        <key>CFBundleIdentifier</key><string>\(identifier)</string>
        <key>CFBundleExecutable</key><string>Run</string>
        </dict></plist>
        """.write(to: app.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)
        let executable = macOS.appendingPathComponent("Run")
        try "#!/bin/sh\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        return app
    }

    func testDroppingSameApplicationTwiceAddsOnce() throws {
        let store = DockStore(persistence: persistence)
        let app = try makeApp("Sample", identifier: "test.dup")
        let count = store.activeProfile.items.count

        XCTAssertEqual(store.addDroppedItems([app], at: 0).added, 1)
        let second = store.addDroppedItems([app], at: 0)

        XCTAssertEqual(second.added, 0)
        XCTAssertEqual(store.activeProfile.items.count, count + 1)
        XCTAssertTrue(store.status.contains("既に Dock にある"))
    }

    func testSameApplicationTwiceInOneDropAddsOnceAndReports() throws {
        let store = DockStore(persistence: persistence)
        let app = try makeApp("Sample", identifier: "test.dup")
        let file = directory.appendingPathComponent("a.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)

        let result = store.addDroppedItems([app, file, app], at: 0)

        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(store.activeProfile.items.prefix(2).map(\.name), ["Sample", "a.txt"])
        XCTAssertTrue(store.status.contains("Sample"))
    }

    func testApplicationAlreadyInDraftIsNotAddedByDrop() throws {
        let store = DockStore(persistence: persistence)
        let app = try makeApp("Sample", identifier: "test.dup")
        store.addChosenItems([app], kind: .application)
        let count = store.editorProfile.items.count

        XCTAssertEqual(store.addDroppedItems([app], at: 0).added, 0)
        XCTAssertEqual(store.editorProfile.items.count, count)
    }

    func testChoosingExistingApplicationIsSkipped() throws {
        let store = DockStore(persistence: persistence)
        let app = try makeApp("Sample", identifier: "test.dup")
        let count = store.editorProfile.items.count

        store.addChosenItems([app, app], kind: .application)
        XCTAssertEqual(store.editorProfile.items.count, count + 1)

        store.addChosenItems([app], kind: .application)
        XCTAssertEqual(store.editorProfile.items.count, count + 1)
        XCTAssertTrue(store.status.contains("既に Dock にある"))
    }

    func testFilesAndFoldersAreNotDeduplicated() throws {
        let store = DockStore(persistence: persistence)
        let file = directory.appendingPathComponent("a.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)
        let count = store.activeProfile.items.count

        store.addDroppedItems([file], at: 0)
        store.addDroppedItems([file], at: 0)

        XCTAssertEqual(store.activeProfile.items.count, count + 2)
    }

    func testExistingDuplicatesInProfileAreKept() throws {
        let app = try makeApp("Sample", identifier: "test.dup")
        let item = DockItem(name: "Sample", kind: .application, target: app.absoluteString)
        let profile = DockProfile(name: "P", items: [item, item])
        let document = DockDocument(profiles: [profile], activeProfileID: profile.id)
        let store = DockStore(persistence: persistence, initial: document)

        store.addChosenItems([directory.appendingPathComponent("x.txt")], kind: .file)

        XCTAssertEqual(store.editorProfile.items.filter { $0.kind == .application }.count, 2)
    }
}
