import XCTest
@testable import DockStudio

@MainActor
final class FinderSelectionTests: XCTestCase {
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

    func testPrepareClassifiesMultipleFilesFoldersAndApplications() throws {
        let file = directory.appendingPathComponent("notes.txt")
        try "notes".write(to: file, atomically: true, encoding: .utf8)
        let folder = directory.appendingPathComponent("Projects", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let app = directory.appendingPathComponent("Editor.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let calls = NSMutableArray()

        let candidates = [file, folder, app].map { url in
            FinderSelectionCandidate.resolve(url) { item in
                calls.add(item.kind.rawValue)
                return nil
            }
        }
        let result = FinderSelectionAddition.prepare(candidates)

        XCTAssertEqual(result.items.map(\.kind), [.file, .folder, .application])
        XCTAssertEqual(result.items.map(\.name), ["notes.txt", "Projects", "Editor"])
        XCTAssertTrue(result.rejected.isEmpty)
        XCTAssertEqual(calls as? [String], ["file", "folder", "application"])
    }

    func testPrepareRejectsNonFileMissingAndValidationFailuresWithReasons() throws {
        let invalidFile = directory.appendingPathComponent("run.sh")
        try "#!/bin/sh\n".write(to: invalidFile, atomically: true, encoding: .utf8)
        let missing = directory.appendingPathComponent("missing.txt")
        let remote = URL(string: "https://example.com/file")!

        let candidates = [invalidFile, missing, remote].map { url in
            FinderSelectionCandidate.resolve(url) { _ in "実行可能ファイルは追加できません。" }
        }
        let result = FinderSelectionAddition.prepare(candidates)

        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.rejected.map(\.name), ["run.sh", "missing.txt", "file"])
        XCTAssertEqual(result.rejected.map(\.reason), [
            "実行可能ファイルは追加できません。",
            "アクセスできないか、存在しません。",
            "ローカル項目ではありません。"
        ])
    }

    func testServiceAddsToActiveProfileWithoutChangingEditingDraft() throws {
        let store = DockStore(persistence: persistence)
        let activeID = store.document.activeProfileID
        let otherID = try XCTUnwrap(store.document.profiles.first(where: { $0.id != activeID })?.id)
        store.editingProfileID = otherID
        store.editorProfile.name = "Unchanged draft"
        store.addItem(DockItem(name: "Draft only", kind: .spacer))
        let draftBefore = store.editorProfile
        let file = directory.appendingPathComponent("notes.txt")
        try "notes".write(to: file, atomically: true, encoding: .utf8)

        let result = store.addFinderSelection([file])

        XCTAssertEqual(result.items.map(\.name), ["notes.txt"])
        XCTAssertEqual(store.document.activeProfileID, activeID)
        XCTAssertEqual(store.activeProfile.items.last?.name, "notes.txt")
        XCTAssertEqual(store.editorProfile, draftBefore)
        XCTAssertTrue(store.hasUnsavedChanges)
    }

    func testServiceReportsRejectedTargetsAndProtectsReadOnlyStorage() throws {
        let writableStore = DockStore(persistence: persistence)
        let absent = directory.appendingPathComponent("gone.txt")
        let rejected = writableStore.addFinderSelection([absent])
        XCTAssertTrue(rejected.items.isEmpty)
        XCTAssertEqual(writableStore.errorMessage, "一部の項目を追加できませんでした。\ngone.txt: アクセスできないか、存在しません。")

        let broken = ProfilePersistence(fileURL: persistence.fileURL)
        try "not json".write(to: broken.fileURL, atomically: true, encoding: .utf8)
        let store = DockStore(persistence: broken)

        let result = store.addFinderSelection([absent])

        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(store.errorMessage, DockDataError.readOnly.localizedDescription)
        XCTAssertEqual(try String(contentsOf: broken.fileURL, encoding: .utf8), "not json")
    }
}
