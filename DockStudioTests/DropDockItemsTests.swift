import XCTest
@testable import DockStudio

@MainActor
final class DropDockItemsTests: XCTestCase {
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

    private func makeFile(_ name: String, contents: String = "data") throws -> URL {
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeFolder(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testDroppedFilesAndFolderAreInsertedInOrderAtIndex() throws {
        let store = DockStore(persistence: persistence)
        let before = store.activeProfile.items
        let first = try makeFile("a.txt")
        let folder = try makeFolder("docs")
        let second = try makeFile("b.txt")

        let result = store.addDroppedItems([first, folder, second], at: 1)

        XCTAssertEqual(result.added, 3)
        XCTAssertTrue(result.rejected.isEmpty)
        let items = store.activeProfile.items
        XCTAssertEqual(items.count, before.count + 3)
        XCTAssertEqual(items[0], before[0])
        XCTAssertEqual(items[1...3].map(\.name), ["a.txt", "docs", "b.txt"])
        XCTAssertEqual(items[1...3].map(\.kind), [.file, .folder, .file])
        XCTAssertEqual(Array(items[4...]), Array(before[1...]))
    }

    func testDroppedItemsPersistWithOrderAcrossRelaunch() throws {
        let store = DockStore(persistence: persistence)
        let first = try makeFile("a.txt")
        let second = try makeFile("b.txt")
        store.addDroppedItems([first, second], at: 0)

        let reloaded = DockStore(persistence: persistence)

        XCTAssertEqual(reloaded.activeProfile.items.prefix(2).map(\.name), ["a.txt", "b.txt"])
        XCTAssertEqual(reloaded.activeProfile.items.prefix(2).compactMap(\.targetURL), [first, second])
    }

    func testDropLeavesOriginalFilesInPlace() throws {
        let store = DockStore(persistence: persistence)
        let file = try makeFile("keep.txt", contents: "keep")
        let folder = try makeFolder("keep-folder")

        store.addDroppedItems([file, folder], at: 0)

        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "keep")
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
    }

    func testOutOfRangeIndexIsClampedToTheSavedItems() throws {
        let store = DockStore(persistence: persistence)
        let count = store.activeProfile.items.count

        store.addDroppedItems([try makeFile("tail.txt")], at: 999)
        XCTAssertEqual(store.activeProfile.items.count, count + 1)
        XCTAssertEqual(store.activeProfile.items.last?.name, "tail.txt")

        store.addDroppedItems([try makeFile("head.txt")], at: -5)
        XCTAssertEqual(store.activeProfile.items.first?.name, "head.txt")
    }

    func testExecutableScriptAndNonFileTargetsAreRejectedWhileOthersAreAdded() throws {
        let store = DockStore(persistence: persistence)
        let count = store.activeProfile.items.count
        let script = try makeFile("run.sh", contents: "#!/bin/sh\n")
        let fakeApp = try makeFolder("Fake.app")
        let missing = directory.appendingPathComponent("missing.txt")
        let web = URL(string: "https://example.com/file")!
        let good = try makeFile("ok.txt")

        let result = store.addDroppedItems([script, fakeApp, missing, web, good], at: 0)

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.rejected.count, 4)
        XCTAssertEqual(store.activeProfile.items.count, count + 1)
        XCTAssertEqual(store.activeProfile.items.first?.name, "ok.txt")
    }

    func testApplicationBundleIsAddedAsApplication() throws {
        let store = DockStore(persistence: persistence)
        let app = directory.appendingPathComponent("Sample.app")
        let macOS = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        <key>CFBundleIdentifier</key><string>test.sample</string>
        <key>CFBundleExecutable</key><string>Sample</string>
        </dict></plist>
        """.write(to: app.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)
        let executable = macOS.appendingPathComponent("Sample")
        try "#!/bin/sh\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let result = store.addDroppedItems([app], at: 0)

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(store.activeProfile.items.first?.kind, .application)
        XCTAssertEqual(store.activeProfile.items.first?.name, "Sample")
    }

    func testDropIsRefusedWhenStorageIsReadOnly() throws {
        try "not json".write(to: persistence.fileURL, atomically: true, encoding: .utf8)
        let store = DockStore(persistence: persistence)
        XCTAssertTrue(store.storageIsReadOnly)

        let result = store.addDroppedItems([try makeFile("a.txt")], at: 0)

        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(try String(contentsOf: persistence.fileURL, encoding: .utf8), "not json")
    }

    func testDropKeepsUnsavedDraftEditsAndAddsItemToDraft() throws {
        let store = DockStore(persistence: persistence)
        store.editorProfile.name = "Draft name"

        store.addDroppedItems([try makeFile("a.txt")], at: 0)

        XCTAssertEqual(store.editorProfile.name, "Draft name")
        XCTAssertEqual(store.editorProfile.items.first?.name, "a.txt")
        XCTAssertEqual(store.activeProfile.items.first?.name, "a.txt")
    }

    func testDropIntoDraftWithDeletedItemsFollowsThePrecedingSavedItem() throws {
        let store = DockStore(persistence: persistence)
        let items = ["a", "b", "c", "d"].map { DockItem(name: $0, kind: .spacer) }
        store.editorProfile.items = items
        XCTAssertTrue(store.saveProfile())
        store.editorProfile.items.removeFirst(2)

        store.addDroppedItems([try makeFile("x.txt")], at: 3)

        XCTAssertEqual(store.activeProfile.items.map(\.name), ["a", "b", "c", "x.txt", "d"])
        XCTAssertEqual(store.editorProfile.items.map(\.name), ["c", "x.txt", "d"])

        store.addDroppedItems([try makeFile("y.txt")], at: 0)
        XCTAssertEqual(store.editorProfile.items.map(\.name), ["y.txt", "c", "x.txt", "d"])

        store.editorProfile.items.removeAll { $0.name == "c" }
        store.addDroppedItems([try makeFile("z.txt")], at: 4)
        XCTAssertEqual(store.activeProfile.items.map(\.name), ["y.txt", "a", "b", "c", "z.txt", "x.txt", "d"])
        XCTAssertEqual(store.editorProfile.items.map(\.name), ["y.txt", "x.txt", "d", "z.txt"])
    }

    func testInsertionIndexFollowsPointerAgainstItemMidpoints() {
        let rects = [CGRect(x: 0, y: 0, width: 50, height: 50), CGRect(x: 50, y: 0, width: 50, height: 50),
                     CGRect(x: 100, y: 0, width: 50, height: 50)]
        XCTAssertEqual(DockDropInsertion.index(at: CGPoint(x: 10, y: 20), frames: rects, vertical: false), 0)
        XCTAssertEqual(DockDropInsertion.index(at: CGPoint(x: 40, y: 20), frames: rects, vertical: false), 1)
        XCTAssertEqual(DockDropInsertion.index(at: CGPoint(x: 80, y: 20), frames: rects, vertical: false), 2)
        XCTAssertEqual(DockDropInsertion.index(at: CGPoint(x: 140, y: 20), frames: rects, vertical: false), 3)
        XCTAssertEqual(DockDropInsertion.index(at: CGPoint(x: 400, y: 20), frames: rects, vertical: false), 3)
        let column = rects.map { CGRect(x: 0, y: $0.minX, width: 50, height: 50) }
        XCTAssertEqual(DockDropInsertion.index(at: CGPoint(x: 20, y: 80), frames: column, vertical: true), 2)
        XCTAssertEqual(DockDropInsertion.index(at: CGPoint(x: 20, y: 80), frames: [], vertical: true), 0)
    }
}
