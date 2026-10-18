import XCTest
@testable import DockStudio

@MainActor
final class DockStoreTests: XCTestCase {
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

    func testDraftsSurviveProfileAndScreenChanges() throws {
        let store = DockStore(persistence: persistence)
        let originalID = store.editingProfileID
        store.editorProfile.name = "Edited work"
        store.addItem(DockItem(name: "Clock", kind: .clock))
        let draft = store.editorProfile
        store.editingProfileID = store.document.profiles[1].id
        store.editorProfile.name = "Edited personal"
        store.editingProfileID = originalID
        XCTAssertEqual(store.editorProfile, draft)
        XCTAssertTrue(store.hasUnsavedChanges)
        XCTAssertNotEqual(store.activeProfile.name, "Edited work")
    }

    func testSaveAndActivatePersistAcrossRelaunch() throws {
        let store = DockStore(persistence: persistence)
        store.editingProfileID = store.document.profiles[1].id
        store.editorProfile.name = "Saved personal"
        store.addItem(DockItem(name: "Clock", kind: .clock))
        store.saveProfile(activate: true)
        let reloaded = DockStore(persistence: persistence)
        XCTAssertEqual(reloaded.activeProfile, store.editorProfile)
        XCTAssertEqual(reloaded.document, store.document)
        XCTAssertFalse(store.hasUnsavedChanges)
    }

    func testKeyboardMovePersistsActiveProfileOrder() throws {
        let store = DockStore(persistence: persistence)
        let original = store.activeProfile.items
        let movedIndex = store.moveActiveItem(original[1].id, by: 1)

        XCTAssertEqual(movedIndex, 2)
        XCTAssertEqual(store.activeProfile.items[2].id, original[1].id)
        XCTAssertEqual(try DockStore(persistence: persistence).activeProfile.items.map(\.id),
                       store.activeProfile.items.map(\.id))
        XCTAssertTrue(store.status.contains("3番目に移動しました"))
    }

    func testFolderDisplayStylePersistsOnOnlyTheSelectedFolder() throws {
        let store = DockStore(persistence: persistence)
        store.addItem(DockItem(name: "Second Folder", kind: .folder, target: "file:///tmp/Second%20Folder/"))
        XCTAssertTrue(store.saveProfile(activate: true))
        let folders = store.activeProfile.items.filter { $0.kind == .folder }
        let selected = try XCTUnwrap(folders.first)
        let other = try XCTUnwrap(folders.dropFirst().first)
        store.editorProfile.name = "Pending profile edit"

        XCTAssertTrue(store.setFolderDisplayStyle(.stack, for: selected.id))
        XCTAssertTrue(store.saveProfile(activate: true))

        let reloaded = try XCTUnwrap(DockStore(persistence: persistence).activeProfile.items.first { $0.id == selected.id })
        let unchanged = try XCTUnwrap(DockStore(persistence: persistence).activeProfile.items.first { $0.id == other.id })
        XCTAssertEqual(reloaded.effectiveFolderDisplayStyle, .stack)
        XCTAssertEqual(unchanged.effectiveFolderDisplayStyle, .folder)
    }

    func testSavingInactiveProfileDoesNotActivateIt() {
        let store = DockStore(persistence: persistence)
        let activeID = store.document.activeProfileID
        store.editingProfileID = store.document.profiles[1].id
        store.editorProfile.name = "Updated"
        store.saveProfile()
        XCTAssertEqual(store.document.activeProfileID, activeID)
        XCTAssertEqual(DockStore(persistence: persistence).document.profiles[1].name, "Updated")
    }

    func testSettingsAreSharedAndPersisted() {
        let store = DockStore(persistence: persistence)
        var settings = store.document.settings
        settings.position = .right
        settings.iconSize = 72
        settings.autoHide = true
        settings.minimizeWindowsIntoAppIcon = true
        store.updateSettings(settings)
        XCTAssertEqual(DockStore(persistence: persistence).document.settings, settings)
    }

    func testFolderDisplayStyleIsSavedPerItem() {
        let store = DockStore(persistence: persistence)
        let folder = DockItem(name: "Folder", kind: .folder, target: "file:///tmp/")
        store.addItem(folder)
        XCTAssertTrue(store.saveProfile())

        XCTAssertTrue(store.updateFolderContentsDisplayStyle(.fan, for: folder.id))

        let reloaded = DockStore(persistence: persistence)
        XCTAssertEqual(reloaded.activeProfile.items.first(where: { $0.id == folder.id })?.folderContentsDisplayStyle, .fan)
    }

    func testManualDockVisibilityToggleIsIndependentOfAutoHide() {
        let store = DockStore(persistence: persistence)
        var settings = store.document.settings
        settings.autoHide = true
        store.updateSettings(settings)

        store.toggleDockVisibility()
        XCTAssertTrue(store.isDockVisible)
        XCTAssertTrue(store.document.settings.autoHide)

        store.toggleDockVisibility()
        XCTAssertFalse(store.isDockVisible)
        XCTAssertTrue(store.document.settings.autoHide)
    }

    func testInvalidSettingsDoNotReplaceDocument() {
        let store = DockStore(persistence: persistence)
        let original = store.document
        var settings = original.settings
        settings.iconSize = 900
        store.updateSettings(settings)
        XCTAssertEqual(store.document, original)
        XCTAssertNotNil(store.errorMessage)
    }

    func testCorruptFileIsNotOverwritten() throws {
        let corrupt = Data("not json".utf8)
        try corrupt.write(to: persistence.fileURL)
        let store = DockStore(persistence: persistence)
        XCTAssertTrue(store.storageIsReadOnly)
        store.createProfile()
        store.saveProfile()
        XCTAssertEqual(try Data(contentsOf: persistence.fileURL), corrupt)
    }

    func testFutureVersionIsNotOverwritten() throws {
        var document = DockStore.preview().document
        document.schemaVersion = 999
        let future = try JSONEncoder().encode(document)
        try future.write(to: persistence.fileURL)
        let store = DockStore(persistence: persistence)
        XCTAssertTrue(store.storageIsReadOnly)
        store.activateProfile(store.document.profiles[1].id)
        XCTAssertEqual(try Data(contentsOf: persistence.fileURL), future)
    }

    func testFailedWriteDoesNotReportSuccessOrChangeDocument() throws {
        let blocker = directory.appendingPathComponent("regular-file")
        try Data().write(to: blocker)
        let store = DockStore(persistence: ProfilePersistence(fileURL: blocker.appendingPathComponent("profiles.json")))
        let original = store.document
        store.editorProfile.name = "Must remain a draft"
        store.saveProfile(activate: true)
        XCTAssertEqual(store.document, original)
        XCTAssertTrue(store.hasUnsavedChanges)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.status, "")
    }

    func testInitialDocumentIncludesRuntimeDownloadsLocation() throws {
        let document = DockStore.initialDocument()
        let downloads = try XCTUnwrap(document.profiles.first?.items.first { $0.name == "Downloads" })

        XCTAssertEqual(downloads.kind, .folder)
        XCTAssertEqual(downloads.target, DockItem.downloadsLocationTarget)
        XCTAssertEqual(downloads.targetURL, DockItem.downloadsDirectoryURL())
        XCTAssertTrue(try XCTUnwrap(document.profiles.first).items.contains { $0.name == "スペーサー" })
    }

    func testExistingProfileIsNotChangedToAddDownloads() throws {
        let profile = DockProfile(name: "Existing", items: [])
        let existing = DockDocument(profiles: [profile], activeProfileID: profile.id)
        try persistence.save(existing)

        let store = DockStore(persistence: persistence)

        XCTAssertEqual(store.document, existing)
        XCTAssertFalse(store.document.profiles.flatMap(\.items).contains { $0.name == "Downloads" })
    }

    func testDownloadsLocationResolvesAgainAfterFolderMoves() throws {
        let downloads = DockItem(name: "Downloads", kind: .folder,
                                target: DockItem.downloadsLocationTarget)
        let original = URL(fileURLWithPath: "/Users/example/Downloads")
        let moved = URL(fileURLWithPath: "/Volumes/Data/Downloads")

        XCTAssertEqual(downloads.resolvedTargetURL(downloadsDirectory: original), original)
        XCTAssertEqual(downloads.resolvedTargetURL(downloadsDirectory: moved), moved)
    }

    func testItemRemovalCanBeUndoneWithOriginalIdentityAndOrder() {
        let store = DockStore.preview()
        let original = store.editorProfile
        let item = original.items[1]
        store.removeItem(item.id)
        XCTAssertEqual(store.editorProfile.items.count, original.items.count - 1)
        store.undoRemoval()
        XCTAssertEqual(store.editorProfile, original)
        XCTAssertFalse(store.canUndoRemoval)
    }

    func testMergeCreatesFreshIdentifiersWithoutReplacingExistingProfiles() {
        let store = DockStore(persistence: persistence)
        let original = store.document
        store.mergeProfiles(original.profiles)
        XCTAssertEqual(store.document.profiles.count, original.profiles.count * 2)
        XCTAssertEqual(Array(store.document.profiles.prefix(original.profiles.count)), original.profiles)
        XCTAssertEqual(store.document.activeProfileID, original.activeProfileID)
        XCTAssertEqual(Set(store.document.profiles.map(\.id)).count, store.document.profiles.count)
        let oldIDs = Set(original.profiles.flatMap(\.items).map(\.id))
        let newIDs = Set(store.document.profiles.dropFirst(original.profiles.count).flatMap(\.items).map(\.id))
        XCTAssertTrue(oldIDs.isDisjoint(with: newIDs))
    }

    func testDeletingActiveProfileSelectsRemainingProfileAndProtectsLastProfile() {
        let store = DockStore.preview()
        store.deleteProfile()
        XCTAssertEqual(store.document.profiles.count, 1)
        XCTAssertEqual(store.document.activeProfileID, store.document.profiles[0].id)
        store.deleteProfile()
        XCTAssertEqual(store.document.profiles.count, 1)
    }

    func testDuplicateCopiesDraftWithoutLosingItsItemKinds() {
        let store = DockStore.preview()
        store.editorProfile.name = "Draft"
        store.addItem(DockItem(name: "Folder", kind: .folder, target: "file:///tmp/"))
        let original = store.editorProfile
        store.duplicateProfile()
        XCTAssertNotEqual(store.editorProfile.id, original.id)
        XCTAssertEqual(store.editorProfile.items.map(\.kind), original.items.map(\.kind))
    }

    func testExportRoundTripAndInvalidLinkRejection() throws {
        let document = DockStore.preview().document
        XCTAssertEqual(try persistence.decode(persistence.encode(document)), document)
        var invalid = document
        invalid.profiles[0].items.append(DockItem(name: "Unsafe", kind: .link, target: "javascript:alert(1)"))
        XCTAssertThrowsError(try persistence.encode(invalid))
    }

    func testNativeDockDecodingPreservesOrderAndSpacers() throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>persistent-apps</key><array>
        <dict><key>tile-type</key><string>file-tile</string><key>tile-data</key><dict>
        <key>file-label</key><string>Safari</string><key>file-data</key><dict>
        <key>_CFURLString</key><string>file:///Applications/Safari.app/</string>
        </dict></dict></dict>
        <dict><key>tile-type</key><string>small-spacer-tile</string></dict>
        </array></dict></plist>
        """
        let items = try NativeDockReader().decodeItems(Data(plist.utf8))
        XCTAssertEqual(items.map(\.kind), [.application, .spacer])
        XCTAssertEqual(items.first?.name, "Safari")
    }

    func testNativeDockUnknownFormatFailsInsteadOfDroppingItems() {
        let plist = "<plist version=\"1.0\"><dict><key>persistent-apps</key><array><dict><key>tile-type</key><string>unknown</string></dict></array></dict></plist>"
        XCTAssertThrowsError(try NativeDockReader().decodeItems(Data(plist.utf8)))
    }

    func testFocusTimerUsesElapsedTimeAcrossPauseAndResume() {
        var session = FocusSession()
        let start = Date(timeIntervalSince1970: 1000)
        session.toggle(at: start)
        XCTAssertEqual(session.seconds(at: start.addingTimeInterval(12)), 1488)
        session.toggle(at: start.addingTimeInterval(12))
        XCTAssertEqual(session.seconds(at: start.addingTimeInterval(200)), 1488)
        session.toggle(at: start.addingTimeInterval(200))
        XCTAssertEqual(session.seconds(at: start.addingTimeInterval(210)), 1478)
    }

    func testCompletedTimerRestartsOnOneClick() {
        var session = FocusSession()
        let start = Date(timeIntervalSince1970: 1000)
        session.toggle(at: start)
        session.toggle(at: start.addingTimeInterval(1600))
        XCTAssertEqual(session.seconds(at: start.addingTimeInterval(1600)), 1500)
    }
}
