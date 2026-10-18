import XCTest
import AppKit
@testable import DockStudio

@MainActor
final class ReviewRegressionTests: XCTestCase {
    private var directory: URL!
    private var persistence: ProfilePersistence!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        persistence = ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json"))
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testArchiveDoesNotContainAbsoluteUserPaths() throws {
        let store = DockStore.preview()
        let home = URL(fileURLWithPath: "/Users/private-test-name")
        var doc = store.document
        doc.profiles[0].items.append(DockItem(name: "Notes", kind: .file, target: home.appendingPathComponent("Documents/notes.txt").absoluteString))
        let data = try JSONEncoder().encode(ProfileArchive(document: doc, home: home))
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("private-test-name"))
        XCTAssertFalse(text.contains("file:"))
        XCTAssertTrue(text.contains("homeRelativePath"))
        let decoded = try JSONDecoder().decode(ProfileArchive.self, from: data).resolve(home: directory)
        XCTAssertEqual(decoded.profiles[0].items.last?.targetURL?.path, directory.appendingPathComponent("Documents/notes.txt").path)
    }

    func testArchiveRejectsPathTraversal() throws {
        var archive = ProfileArchive(document: DockStore.preview().document)
        archive.profiles[0].items.append(.init(name: "Escape", kind: .file, homeRelativePath: "../outside.txt"))
        XCTAssertThrowsError(try archive.resolve(home: directory))
    }

    func testImportWaitsForConfirmationAndOverridesUntrustedApprovalFlags() throws {
        let store = DockStore(persistence: persistence)
        let original = store.document
        var incoming = original
        incoming.profiles[0].items[0].requiresLaunchConfirmation = false
        try store.stageImport(persistence.encode(incoming))
        XCTAssertEqual(store.document, original)
        XCTAssertNotNil(store.pendingImport)
        store.confirmImport(restoreSettings: false)
        XCTAssertNil(store.pendingImport)
        XCTAssertTrue(store.document.profiles.last!.items.allSatisfy { $0.requiresLaunchConfirmation == true })
    }

    func testInvalidApplicationReferenceCannotBeImported() throws {
        var document = DockStore.preview().document
        document.profiles[0].items = [DockItem(name: "Safari", kind: .application, target: "file:///bin/sh")]
        let data = try JSONEncoder().encode(document)
        XCTAssertThrowsError(try ProfileArchive.decode(data))
    }

    func testScriptsAndExecutablesCannotMasqueradeAsDocuments() throws {
        let script = directory.appendingPathComponent("disguised.txt")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        XCTAssertThrowsError(try ItemLaunchPolicy().validate(DockItem(name: "Notes", kind: .file, target: script.absoluteString)))
        let command = directory.appendingPathComponent("launch.command")
        try Data("exit 0".utf8).write(to: command)
        XCTAssertThrowsError(try ItemLaunchPolicy().validate(DockItem(name: "Notes", kind: .file, target: command.absoluteString)))
    }

    func testFakeAppBundleCannotBeLaunched() throws {
        let fake = directory.appendingPathComponent("Fake.app")
        try FileManager.default.createDirectory(at: fake, withIntermediateDirectories: true)
        XCTAssertThrowsError(try ItemLaunchPolicy().validate(DockItem(name: "Safari", kind: .application, target: fake.absoluteString)))
    }

    func testNormalDocumentCanBeValidatedWithoutOpeningIt() throws {
        let file = directory.appendingPathComponent("notes.txt")
        try Data("example".utf8).write(to: file)
        XCTAssertEqual(try ItemLaunchPolicy().validate(DockItem(name: "Notes", kind: .file, target: file.absoluteString)).path,
                       file.resolvingSymlinksInPath().path)
    }

    func testDraftsSurviveTerminationAndCanAllBeSaved() throws {
        let first = DockStore(persistence: persistence)
        let firstID = first.editingProfileID
        first.editorProfile.name = "Recovered work"
        first.editingProfileID = first.document.profiles[1].id
        first.editorProfile.name = "Recovered personal"
        let reloaded = DockStore(persistence: persistence)
        XCTAssertTrue(reloaded.hasPendingDrafts)
        reloaded.editingProfileID = firstID
        XCTAssertEqual(reloaded.editorProfile.name, "Recovered work")
        XCTAssertTrue(reloaded.saveAllDrafts())
        XCTAssertFalse(DockStore(persistence: persistence).hasPendingDrafts)
        XCTAssertEqual(try persistence.load()?.profiles.map(\.name), ["Recovered work", "Recovered personal"])
    }

    func testInvalidDraftBlocksSaveAllAndRemainsRecoverable() throws {
        let store = DockStore(persistence: persistence)
        store.editorProfile.name = ""
        XCTAssertFalse(store.saveAllDrafts())
        XCTAssertTrue(store.hasPendingDrafts)
        let reloaded = DockStore(persistence: persistence)
        XCTAssertEqual(reloaded.editorProfile.name, "")
        XCTAssertFalse(reloaded.storageIsReadOnly)
    }

    func testDeletedDraftIsNotResurrected() {
        let store = DockStore(persistence: persistence)
        let deletedID = store.editingProfileID
        store.editorProfile.name = "Draft to delete"
        store.deleteProfile()
        let reloaded = DockStore(persistence: persistence)
        XCTAssertFalse(reloaded.document.profiles.contains(where: { $0.id == deletedID }))
        XCTAssertFalse(reloaded.hasPendingDrafts)
    }

    func testReadOnlyFallbackCannotBeExportedAndCanBeReloaded() throws {
        try Data("broken".utf8).write(to: persistence.fileURL)
        let store = DockStore(persistence: persistence)
        XCTAssertTrue(store.isUsingFallbackData)
        XCTAssertThrowsError(try store.archiveData())
        var repaired = DockStore.preview().document
        repaired.profiles[0].name = "Recovered saved profile"
        try persistence.save(repaired)
        store.retryLoad()
        XCTAssertFalse(store.storageIsReadOnly)
        XCTAssertFalse(store.isUsingFallbackData)
        XCTAssertEqual(store.document, repaired)
    }

    func testCorruptRecoveryFileDoesNotMislabelValidSavedDataAsSample() throws {
        let document = DockStore.preview().document
        try persistence.save(document)
        try Data("broken".utf8).write(to: persistence.draftsURL)
        let store = DockStore(persistence: persistence)
        XCTAssertTrue(store.storageIsReadOnly)
        XCTAssertFalse(store.isUsingFallbackData)
        XCTAssertEqual(store.document, document)
        XCTAssertThrowsError(try store.archiveData())
        XCTAssertEqual(try Data(contentsOf: persistence.draftsURL), Data("broken".utf8))
    }

    func testRunningAppsAreDeduplicatedAcrossURLVariantsAndDuplicateInstances() {
        let store = DockStore.preview()
        let pinned = DockItem(name: "Pinned", kind: .application, target: "file:///Applications/Example.app/")
        store.editorProfile.items = [pinned]
        store.saveProfile()
        var settings = store.document.settings
        settings.showRunningApps = true
        store.updateSettings(settings)
        let duplicate = DockItem(name: "Running", kind: .application, target: "file:///Applications/Example.app")
        let extra = DockItem(name: "Extra", kind: .application, target: "file:///Applications/Extra.app")
        store.runningItems = [duplicate, extra, extra]
        XCTAssertEqual(store.displayedItems.count, 2)
        XCTAssertEqual(Set(store.displayedItems.map(\.id)).count, 2)
    }

    func testPrimaryScreenSelectionIsStableAndMissingExplicitScreenFallsBack() {
        XCTAssertEqual(DisplayOption.preferredID(selectedID: nil, availableIDs: [101, 202]), 101)
        XCTAssertEqual(DisplayOption.preferredID(selectedID: 202, availableIDs: [101, 202]), 202)
        XCTAssertEqual(DisplayOption.preferredID(selectedID: 303, availableIDs: [101, 202]), 101)
    }

    func testEdgeFollowingSelectsTheDisplayAtItsBottomEdgeAcrossDifferentLayouts() {
        let screens = [
            DockDisplayGeometry.Screen(id: 101, frame: NSRect(x: 0, y: 0, width: 1440, height: 900),
                                       visibleFrame: NSRect(x: 0, y: 0, width: 1440, height: 878)),
            DockDisplayGeometry.Screen(id: 202, frame: NSRect(x: -1280, y: 900, width: 1280, height: 1024),
                                       visibleFrame: NSRect(x: -1280, y: 900, width: 1280, height: 1002))
        ]
        let size = NSSize(width: 600, height: 80)

        XCTAssertEqual(DockDisplayGeometry.targetDisplayID(screens: screens, selectedID: 101, mode: .edgeFollowing,
                                                            pointer: NSPoint(x: -640, y: 902), position: .bottom,
                                                            panelSize: size), 202)
        XCTAssertEqual(DockDisplayGeometry.targetDisplayID(screens: screens, selectedID: 101, mode: .selectedDisplay,
                                                            pointer: NSPoint(x: -640, y: 902), position: .bottom,
                                                            panelSize: size), 101)
        XCTAssertEqual(DockDisplayGeometry.targetDisplayID(screens: screens, selectedID: 202, mode: .edgeFollowing,
                                                            pointer: NSPoint(x: -640, y: 1200), position: .bottom,
                                                            panelSize: size), 202)
        XCTAssertEqual(DockDisplayGeometry.targetDisplayID(screens: screens, selectedID: 303, mode: .edgeFollowing,
                                                            pointer: NSPoint(x: 720, y: 2), position: .bottom,
                                                            panelSize: size), 101)
    }

    func testEdgeFollowingUsesLeftAndRightEdgesOnTallAndWideDisplays() {
        let screens = [
            DockDisplayGeometry.Screen(id: 101, frame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                                       visibleFrame: NSRect(x: 0, y: 0, width: 1920, height: 1058)),
            DockDisplayGeometry.Screen(id: 202, frame: NSRect(x: 1920, y: -120, width: 900, height: 1600),
                                       visibleFrame: NSRect(x: 1920, y: -120, width: 900, height: 1578))
        ]

        XCTAssertEqual(DockDisplayGeometry.targetDisplayID(screens: screens, selectedID: 101, mode: .edgeFollowing,
                                                            pointer: NSPoint(x: 1922, y: 680), position: .left,
                                                            panelSize: NSSize(width: 80, height: 900)), 202)
        XCTAssertEqual(DockDisplayGeometry.targetDisplayID(screens: screens, selectedID: 101, mode: .edgeFollowing,
                                                            pointer: NSPoint(x: 2818, y: 680), position: .right,
                                                            panelSize: NSSize(width: 80, height: 900)), 202)
    }

    func testAutoHideWaitsAfterEnablingAndAfterShowingAgain() {
        let start = Date(timeIntervalSince1970: 100)
        var state = DockVisibilityState()
        state.update(visible: true, autoHide: false, hovering: false, interacting: false, now: start)
        state.update(visible: true, autoHide: true, hovering: false, interacting: false, now: start.addingTimeInterval(20))
        XCTAssertFalse(state.isCollapsed)
        state.update(visible: true, autoHide: true, hovering: false, interacting: false, now: start.addingTimeInterval(21.1))
        XCTAssertTrue(state.isCollapsed)
        state.update(visible: false, autoHide: true, hovering: false, interacting: false, now: start.addingTimeInterval(30))
        state.update(visible: true, autoHide: true, hovering: false, interacting: false, now: start.addingTimeInterval(40))
        XCTAssertFalse(state.isCollapsed)
    }

    func testDragRevealRemainsVisibleUntilDragEndsAndThenUsesAutoHideDelay() {
        let start = Date(timeIntervalSince1970: 100)
        var state = DockVisibilityState()
        state.update(visible: true, autoHide: true, hovering: false, interacting: false, now: start)
        state.update(visible: true, autoHide: true, hovering: false, interacting: false,
                     draggingOverRevealArea: true, now: start.addingTimeInterval(1.1))
        XCTAssertFalse(state.isCollapsed)
        state.update(visible: true, autoHide: true, hovering: false, interacting: false,
                     now: start.addingTimeInterval(1.5))
        XCTAssertFalse(state.isCollapsed)
        state.update(visible: true, autoHide: true, hovering: false, interacting: false,
                     now: start.addingTimeInterval(2.2))
        XCTAssertTrue(state.isCollapsed)
    }

    func testOpenPopoverOrMenuPreventsAutoHideAndRestartsDelay() {
        let start = Date(timeIntervalSince1970: 100)
        var state = DockVisibilityState()
        state.update(visible: true, autoHide: true, hovering: false, interacting: false, now: start)
        state.update(visible: true, autoHide: true, hovering: false, interacting: true, now: start.addingTimeInterval(20))
        XCTAssertFalse(state.isCollapsed)
        state.update(visible: true, autoHide: true, hovering: false, interacting: false, now: start.addingTimeInterval(20.5))
        XCTAssertFalse(state.isCollapsed)
        state.update(visible: true, autoHide: true, hovering: false, interacting: false, now: start.addingTimeInterval(21.1))
        XCTAssertTrue(state.isCollapsed)
    }

    func testShowingCustomDockWhileInNativeModeEnablesBoth() throws {
        let store = DockStore(persistence: persistence)
        var settings = store.document.settings
        settings.mode = .native
        store.updateSettings(settings)
        store.toggleDockVisibility()
        XCTAssertTrue(store.isDockEffectivelyVisible)
        XCTAssertEqual(try persistence.load()?.settings.mode, .both)
    }

    func testImportCanRestoreSettingsAndActiveProfileOrLeaveThemUnchanged() throws {
        let incoming = DockStore.preview()
        var settings = incoming.document.settings
        settings.position = .right
        settings.autoHide = true
        settings.iconSize = 70
        incoming.updateSettings(settings)
        incoming.activateProfile(incoming.document.profiles[1].id)
        let data = try incoming.archiveData()
        let copyOnly = DockStore.preview()
        let originalSettings = copyOnly.document.settings
        try copyOnly.stageImport(data)
        copyOnly.confirmImport(restoreSettings: false)
        XCTAssertEqual(copyOnly.document.settings, originalSettings)
        let restore = DockStore(persistence: persistence)
        try restore.stageImport(data)
        restore.confirmImport(restoreSettings: true)
        XCTAssertEqual(restore.document.settings, settings)
        XCTAssertEqual(restore.activeProfile.name, incoming.activeProfile.name + " 2")
        XCTAssertEqual(try persistence.load(), restore.document)
    }

    func testSliderChangesAreStagedUntilCommitted() throws {
        let store = DockStore(persistence: persistence)
        let original = store.document.settings.iconSize
        for value in stride(from: 40.0, through: 74.0, by: 2) { store.stageIconSize(value) }
        XCTAssertEqual(store.document.settings.iconSize, original)
        XCTAssertEqual(store.effectiveIconSize, 74)
        XCTAssertNil(try persistence.load())
        XCTAssertTrue(store.finishIconSizeEditing())
        XCTAssertEqual(try persistence.load()?.settings.iconSize, 74)
    }

    func testMissingNativeDockArrayIsEmptyAndMalformedInputHasReadableError() throws {
        let empty = Data("<plist version=\"1.0\"><dict/></plist>".utf8)
        XCTAssertTrue(try NativeDockReader().decodeItems(empty).isEmpty)
        XCTAssertThrowsError(try NativeDockReader().decodeItems(Data("bad plist".utf8))) { error in
            XCTAssertTrue(error.localizedDescription.contains("unsupported format"))
        }
    }

    func testProcessReadsLargeStderrWithoutBlockingMainActor() async throws {
        let output = try await AsyncProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "head -c 1048576 /dev/zero >&2; printf completed"])
        XCTAssertEqual(output.status, 0)
        XCTAssertEqual(output.stderr.count, 1048576)
        XCTAssertEqual(String(decoding: output.stdout, as: UTF8.self), "completed")
    }

    func testProcessTimeoutTerminatesOnlyItsOwnChild() async throws {
        let output = try await AsyncProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"], timeout: 0.05)
        XCTAssertTrue(output.timedOut)
        XCTAssertNotEqual(output.status, 0)
    }

    func testProcessTimeoutAlsoStopsChildIgnoringTerminationSignal() async throws {
        let output = try await AsyncProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "trap '' TERM; while :; do :; done"], timeout: 0.05)
        XCTAssertTrue(output.timedOut)
        XCTAssertNotEqual(output.status, 0)
    }

    func testDraftRecoveryFailureIsReportedAndDoesNotDiscardDraft() throws {
        let blocker = directory.appendingPathComponent("blocked-directory")
        try Data().write(to: blocker)
        let store = DockStore(persistence: ProfilePersistence(fileURL: blocker.appendingPathComponent("profiles.json")))
        store.editorProfile.name = "Unsaved"
        XCTAssertTrue(store.draftRecoveryFailed)
        XCTAssertTrue(store.hasPendingDrafts)
        XCTAssertFalse(store.saveAllDrafts())
        XCTAssertTrue(store.hasPendingDrafts)
    }

    func testOrphanedDraftFileIsPreservedWhenSavedConfigurationIsMissing() throws {
        let draft = DockStore.preview().editorProfile
        try persistence.saveDrafts([draft])
        let original = try Data(contentsOf: persistence.draftsURL)
        let store = DockStore(persistence: persistence)
        XCTAssertTrue(store.storageIsReadOnly)
        store.createProfile()
        XCTAssertEqual(try Data(contentsOf: persistence.draftsURL), original)
        XCTAssertNil(try persistence.load())
    }

    func testSliderWriteFailureRollsBackAndDoesNotRepeatOnFinish() throws {
        let blocker = directory.appendingPathComponent("blocked-directory")
        try Data().write(to: blocker)
        let store = DockStore(persistence: ProfilePersistence(fileURL: blocker.appendingPathComponent("profiles.json")))
        let original = store.document.settings.iconSize
        store.stageIconSize(70)
        XCTAssertFalse(store.finishIconSizeEditing())
        XCTAssertEqual(store.effectiveIconSize, original)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(store.finishIconSizeEditing())
    }

    func testNativeModeVisibilityDoesNotPretendToSucceedWhenSavingFails() throws {
        let blocker = directory.appendingPathComponent("blocked-directory")
        try Data().write(to: blocker)
        var document = DockStore.preview().document
        document.settings.mode = .native
        let store = DockStore(persistence: ProfilePersistence(fileURL: blocker.appendingPathComponent("profiles.json")), initial: document)
        store.toggleDockVisibility()
        XCTAssertFalse(store.isDockEffectivelyVisible)
        XCTAssertEqual(store.document.settings.mode, .native)
        XCTAssertNotNil(store.errorMessage)
    }
}
