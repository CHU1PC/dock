import ServiceManagement
import XCTest
@testable import DockStudio

private final class FakeLoginItemService: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    var registerCalls = 0
    var unregisterCalls = 0
    var failure: Error?

    func register() throws {
        registerCalls += 1
        if let failure { throw failure }
        status = .enabled
    }

    func unregister() throws {
        unregisterCalls += 1
        if let failure { throw failure }
        status = .notRegistered
    }
}

@MainActor
final class LoginRestoreTests: XCTestCase {
    private func makePreferences() -> UserDefaults {
        let suiteName = "LoginRestoreTests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { preferences.removePersistentDomain(forName: suiteName) }
        return preferences
    }

    private func makeDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func makeStore(_ directory: URL, service: FakeLoginItemService = FakeLoginItemService()) -> DockStore {
        DockStore(persistence: ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json")),
                  loginItem: LoginItemController(service: service))
    }

    func testEnablingAndDisablingCallsServiceOnce() {
        let service = FakeLoginItemService()
        let controller = LoginItemController(service: service)
        XCTAssertFalse(controller.isOn)
        controller.setEnabled(true)
        XCTAssertEqual(service.registerCalls, 1)
        XCTAssertEqual(service.unregisterCalls, 0)
        XCTAssertEqual(controller.state, .enabled)
        controller.setEnabled(false)
        XCTAssertEqual(service.unregisterCalls, 1)
        XCTAssertEqual(controller.state, .disabled)
        XCTAssertNil(controller.message)
    }

    func testRegistrationFailureExplainsAndKeepsState() {
        let service = FakeLoginItemService()
        service.failure = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "denied"])
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        XCTAssertFalse(controller.isOn)
        XCTAssertTrue(controller.message?.contains("登録に失敗") == true)
        XCTAssertTrue(controller.message?.contains("denied") == true)
    }

    func testExternalChangesAreReflectedOnRefresh() {
        let service = FakeLoginItemService()
        let controller = LoginItemController(service: service)
        service.status = .requiresApproval
        controller.refresh()
        XCTAssertTrue(controller.isOn)
        XCTAssertEqual(controller.state, .requiresApproval)
        XCTAssertNotNil(controller.message)
        service.status = .notRegistered
        controller.refresh()
        XCTAssertFalse(controller.isOn)
        XCTAssertNil(controller.message)
    }

    func testLoginItemStateDistinguishesIntentionalUnregisterFromSystemDisablement() {
        XCTAssertEqual(LoginItemState.resolve(status: .notRegistered, userEnabled: false), .disabled)
        XCTAssertEqual(LoginItemState.resolve(status: .notRegistered, userEnabled: true), .disabledBySystem)
        XCTAssertEqual(LoginItemState.resolve(status: .requiresApproval, userEnabled: true), .requiresApproval)
        XCTAssertEqual(LoginItemState.resolve(status: .requiresApproval, userEnabled: false), .requiresApproval)
        XCTAssertEqual(LoginItemState.resolve(status: .enabled, userEnabled: false), .enabled)
        XCTAssertFalse(LoginItemState.disabled.shouldOpenSystemSettings)
        XCTAssertTrue(LoginItemState.disabledBySystem.shouldOpenSystemSettings)
        XCTAssertTrue(LoginItemState.requiresApproval.shouldOpenSystemSettings)
    }

    func testSystemDisablementAfterRegistrationIsPersistedAndExplained() {
        let service = FakeLoginItemService()
        let preferences = makePreferences()
        let controller = LoginItemController(service: service, preferences: preferences)
        controller.setEnabled(true)

        service.status = .notRegistered
        let refreshed = LoginItemController(service: service, preferences: preferences)

        XCTAssertEqual(refreshed.state, .disabledBySystem)
        XCTAssertFalse(refreshed.isOn)
        XCTAssertTrue(refreshed.message?.contains("システム設定") == true)
    }

    func testIntentionalUnregisterClearsPersistedEnabledPreference() {
        let service = FakeLoginItemService()
        let controller = LoginItemController(service: service, preferences: makePreferences())
        controller.setEnabled(true)
        controller.setEnabled(false)

        XCTAssertEqual(controller.state, .disabled)
        XCTAssertNil(controller.message)
    }

    func testNotFoundMeansNotRegisteredWithoutWarning() {
        let service = FakeLoginItemService()
        service.status = .notFound
        let controller = LoginItemController(service: service)
        XCTAssertFalse(controller.isOn)
        XCTAssertEqual(controller.state, .disabled)
        XCTAssertNil(controller.message)
        controller.refresh()
        XCTAssertNil(controller.message)
        controller.setEnabled(true)
        XCTAssertEqual(service.registerCalls, 1)
        XCTAssertTrue(controller.isOn)
        XCTAssertNil(controller.message)
    }

    func testFailedRegisterFromNotFoundShowsErrorOnlyThen() {
        let service = FakeLoginItemService()
        service.status = .notFound
        service.failure = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "no such app"])
        let controller = LoginItemController(service: service)
        XCTAssertNil(controller.message)
        controller.setEnabled(true)
        XCTAssertFalse(controller.isOn)
        XCTAssertTrue(controller.message?.contains("no such app") == true)
    }

    func testVisibleStateIsRestoredAfterRelaunch() {
        let directory = makeDirectory()
        let store = makeStore(directory)
        XCTAssertFalse(store.isDockVisible)
        store.isDockVisible = true
        XCTAssertTrue(makeStore(directory).isDockVisible)
    }

    func testIntentionalHideIsRestoredAsHidden() {
        let directory = makeDirectory()
        let store = makeStore(directory)
        store.isDockVisible = true
        store.isDockVisible = false
        XCTAssertFalse(makeStore(directory).isDockVisible)
    }

    func testRelaunchKeepsAutoHideAndActiveProfile() throws {
        let directory = makeDirectory()
        let store = makeStore(directory)
        var settings = store.document.settings
        settings.autoHide = true
        XCTAssertTrue(store.updateSettings(settings))
        store.activateProfile(store.document.profiles[1].id)
        store.isDockVisible = true
        let reloaded = makeStore(directory)
        XCTAssertTrue(reloaded.isDockVisible)
        XCTAssertTrue(reloaded.document.settings.autoHide)
        XCTAssertEqual(reloaded.document.activeProfileID, store.document.activeProfileID)
    }

    func testMissingStateFileStartsHiddenWithoutNotice() {
        let store = makeStore(makeDirectory())
        XCTAssertFalse(store.isDockVisible)
        XCTAssertNil(store.launchStateNotice)
    }

    func testCorruptStateStartsHiddenAndExplains() throws {
        let directory = makeDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = LaunchRestorePersistence.url(besides: directory.appendingPathComponent("profiles.json"))
        try Data("not json".utf8).write(to: url)
        let store = makeStore(directory)
        XCTAssertFalse(store.isDockVisible)
        XCTAssertNotNil(store.launchStateNotice)
        store.isDockVisible = true
        XCTAssertNil(store.launchStateNotice)
        XCTAssertTrue(makeStore(directory).isDockVisible)
    }

    func testSavingVisibilityDoesNotTouchProfilesFile() throws {
        let directory = makeDirectory()
        let store = makeStore(directory)
        XCTAssertTrue(store.updateSettings(store.document.settings))
        let profiles = directory.appendingPathComponent("profiles.json")
        let before = try Data(contentsOf: profiles)
        store.isDockVisible = true
        XCTAssertEqual(try Data(contentsOf: profiles), before)
    }

    func testUnwritableStateLocationReportsNotice() throws {
        let directory = makeDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = LaunchRestorePersistence.url(besides: directory.appendingPathComponent("profiles.json"))
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        let store = makeStore(directory)
        store.isDockVisible = true
        XCTAssertNotNil(store.launchStateNotice)
    }
}
