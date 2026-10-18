import AppKit
import SwiftUI
import XCTest
@testable import DockStudio

final class NativeDockTileRegressionTests: XCTestCase {
    @MainActor
    func testClosingLastWindowKeepsDockUtilityRunning() {
        let delegate = DockAppDelegate()
        delegate.tileOnly = true
        XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
        delegate.tileOnly = false
        XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }

    @MainActor
    func testWakeNotificationRecomputesElapsedTime() {
        let window = NSWindow()
        let controller = NativeDockTileController(store: .preview(), tile: window.dockTile)
        controller.start()
        defer { controller.stop() }
        let beforeSleep = Date().addingTimeInterval(-1600)
        controller.state.toggle(at: beforeSleep)
        controller.refresh(at: beforeSleep)
        XCTAssertEqual(controller.state.seconds, 1500)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        XCTAssertEqual(controller.state.seconds, 0)
        XCTAssertEqual(controller.state.status, "完了")
    }

    @MainActor
    func testOrdinaryLaunchDoesNotInstallTileOrMenu() {
        let delegate = DockAppDelegate()
        let store = DockStore.preview()
        delegate.store = store
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        XCTAssertNil(delegate.applicationDockMenu(NSApplication.shared))
    }

    @MainActor
    func testSavedProfilesAreCopiedWithoutWritingTheirSource() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json"))
        let original = DockStore.preview().document
        try persistence.save(original)
        let bytes = try Data(contentsOf: persistence.fileURL)
        let preview = NativeDockTilePreview(persistence: persistence)
        XCTAssertEqual(preview.store.document, original)
        XCTAssertTrue(preview.notice.contains("保存済みプロファイル"))
        preview.store.activateProfile(original.profiles[1].id)
        var draft = preview.store.editorProfile
        draft.name = "Temporary edit"
        preview.store.editorProfile = draft
        XCTAssertTrue(preview.store.saveProfile())
        XCTAssertEqual(try Data(contentsOf: persistence.fileURL), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: persistence.draftsURL.path))
    }

    @MainActor
    func testMissingAndCorruptSourcesExplicitlyExplainSampleData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json"))
        XCTAssertTrue(NativeDockTilePreview(persistence: persistence).notice.contains("設定がない"))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bytes = Data("broken".utf8)
        try bytes.write(to: persistence.fileURL)
        XCTAssertTrue(NativeDockTilePreview(persistence: persistence).notice.contains("読み込めない"))
        XCTAssertEqual(try Data(contentsOf: persistence.fileURL), bytes)
    }

    @MainActor
    func testMenuUpdatesWhenTimerCompletesWhileItRemainsOpen() {
        let controller = NativeDockTileController(store: .preview(), tile: NSWindow().dockTile)
        let menu = controller.makeMenu()
        XCTAssertEqual(menu.item(withTag: 100)?.title, "25 分タイマーを開始")
        let date = Date()
        controller.state.toggle(at: date)
        controller.refresh(at: date)
        XCTAssertEqual(menu.item(withTag: 100)?.title, "タイマーを一時停止")
        controller.refresh(at: date.addingTimeInterval(1600))
        XCTAssertEqual(menu.item(withTag: 100)?.title, "25 分タイマーを開始")
        XCTAssertEqual(menu.item(withTag: 102)?.state, .on)
        XCTAssertTrue(menu.items.contains { $0.title.contains("配置は変更しません") })
    }

    @MainActor
    func testBackgroundActivityMenuGuidesToLoginItemsWithoutTerminatingApps() {
        var openedLoginItemsSettings = false
        let controller = NativeDockTileController(
            store: .preview(),
            tile: NSWindow().dockTile,
            openLoginItemsSettings: { openedLoginItemsSettings = true }
        )
        let menu = controller.makeMenu()
        let settingsItem = menu.items.first { $0.title == "バックグラウンド実行を設定…" }

        XCTAssertNotNil(settingsItem)
        XCTAssertTrue(menu.items.contains { $0.title.contains("ログイン項目と機能拡張") && $0.title.contains("バックグラウンドでのアプリのアクティビティ") })
        XCTAssertTrue(menu.items.contains { $0.title.contains("同期や自動更新が止まる場合があります") })
        XCTAssertTrue(menu.items.contains { $0.title.contains("Stop Running in Background") && $0.title.contains("通常終了や強制終了とは異なる設定です") })
        XCTAssertFalse(openedLoginItemsSettings)
        XCTAssertTrue(NSApplication.shared.sendAction(settingsItem!.action!, to: settingsItem!.target, from: settingsItem))
        XCTAssertTrue(openedLoginItemsSettings)
    }

    @MainActor
    func testProfileSelectionDoesNotReuseStaleErrorsAndConsumesNewErrors() {
        let store = DockStore.preview()
        let controller = NativeDockTileController(store: store, tile: NSWindow().dockTile)
        store.errorMessage = "Unrelated old error"
        XCTAssertNil(controller.activateProfile(store.document.profiles[1].id))
        XCTAssertNil(store.errorMessage)
        XCTAssertNotNil(controller.activateProfile(UUID()))
        XCTAssertNil(store.errorMessage)
    }

    @MainActor
    func testStopRemovesTileAndCanStartAgain() {
        let window = NSWindow()
        let controller = NativeDockTileController(store: .preview(), tile: window.dockTile)
        controller.start()
        XCTAssertTrue(controller.isStarted)
        XCTAssertNotNil(window.dockTile.contentView)
        controller.stop()
        XCTAssertFalse(controller.isStarted)
        XCTAssertNil(window.dockTile.contentView)
        controller.start()
        XCTAssertTrue(controller.isStarted)
        controller.stop()
    }

    @MainActor
    func testDetailViewDoesNotRetainController() {
        var controller: NativeDockTileController? = NativeDockTileController(store: .preview(), tile: NSWindow().dockTile)
        weak var reference = controller
        let detail = NativeDockTileDetail(controller: controller!)
        controller = nil
        XCTAssertNil(reference)
        detail.toggleTimer()
    }

    @MainActor
    func testWaitingStateAndWallClockRecoveryAfterLongDelay() {
        let state = NativeDockTileState()
        XCTAssertEqual(state.status, "待機")
        let date = Date()
        state.toggle(at: date)
        state.now = date.addingTimeInterval(2000)
        XCTAssertEqual(state.status, "完了")
        XCTAssertEqual(state.seconds, 0)
        state.reset()
        XCTAssertEqual(state.status, "待機")
    }
}
