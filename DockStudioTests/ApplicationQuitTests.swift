import XCTest
@testable import DockStudio

private final class FakeApplication: QuittableApplication {
    let bundleIdentifier: String?
    let bundleURL: URL? = URL(fileURLWithPath: "/Applications/Fake.app")
    let processIdentifier: pid_t = 123
    var isTerminated: Bool
    let accepts: Bool
    private(set) var terminateCalls = 0
    private(set) var activateCalls = 0
    private(set) var forceTerminateCalls = 0
    init(_ id: String, isTerminated: Bool = false, accepts: Bool = true) {
        bundleIdentifier = id; self.isTerminated = isTerminated; self.accepts = accepts
    }
    func terminate() -> Bool { terminateCalls += 1; return accepts }
    func activate() { activateCalls += 1 }
    func forceTerminate() -> Bool { forceTerminateCalls += 1; return accepts }
}

private struct FakeQuitPromptDetector: QuitPromptDetecting {
    let result: QuitPromptDetection

    func detection(for application: any QuittableApplication) -> QuitPromptDetection { result }
}

@MainActor
final class ApplicationQuitTests: XCTestCase {
    private func quitter(
        _ apps: [FakeApplication],
        schedule: @escaping (@escaping @MainActor () -> Void) -> Void = { _ in },
        promptDetection: QuitPromptDetection = .detected
    ) -> ApplicationQuitter {
        ApplicationQuitter(runningApplications: { id in apps.filter { $0.bundleIdentifier == id } },
                           excludedBundleIdentifiers: ["com.apple.finder", "com.example.self"],
                           promptDetector: FakeQuitPromptDetector(result: promptDetection),
                           scheduleActivation: schedule)
    }

    private func app(_ id: String) -> DockItem {
        DockItem(name: id, kind: .application, target: nil, bundleIdentifier: id)
    }

    func testRunningApplicationReceivesOneTerminate() {
        let calculator = FakeApplication("com.example.calc")
        XCTAssertEqual(quitter([calculator]).quit(app("com.example.calc")), .requested)
        XCTAssertEqual(calculator.terminateCalls, 1)
    }

    func testOtherApplicationsAreNotTerminated() {
        let other = FakeApplication("com.example.other")
        XCTAssertEqual(quitter([other]).quit(app("com.example.calc")), .notRunning)
        XCTAssertEqual(other.terminateCalls, 0)
    }

    func testTerminatedApplicationIsTreatedAsNotRunning() {
        let gone = FakeApplication("com.example.calc", isTerminated: true)
        XCTAssertEqual(quitter([gone]).quit(app("com.example.calc")), .notRunning)
        XCTAssertEqual(gone.terminateCalls, 0)
    }

    func testFinderAndSelfAreNotQuittable() {
        let finder = FakeApplication("com.apple.finder")
        let own = FakeApplication("com.example.self")
        let q = quitter([finder, own])
        XCTAssertEqual(q.quit(app("com.apple.finder")), .notQuittable)
        XCTAssertEqual(q.quit(app("com.example.self")), .notQuittable)
        XCTAssertEqual(finder.terminateCalls + own.terminateCalls, 0)
    }

    func testNonApplicationItemsAreNotQuittable() {
        let folder = DockItem(name: "f", kind: .folder, target: nil, bundleIdentifier: "com.example.calc")
        let calculator = FakeApplication("com.example.calc")
        XCTAssertEqual(quitter([calculator]).quit(folder), .notQuittable)
        XCTAssertEqual(calculator.terminateCalls, 0)
    }

    func testRejectedTerminateIsReported() {
        let stubborn = FakeApplication("com.example.calc", accepts: false)
        XCTAssertEqual(quitter([stubborn]).quit(app("com.example.calc")), .rejected)
        XCTAssertEqual(stubborn.activateCalls, 0)
    }

    func testSentTerminateRequestSchedulesActivation() {
        let calculator = FakeApplication("com.example.calc")
        var scheduled: [@MainActor () -> Void] = []
        let q = quitter([calculator]) { scheduled.append($0) }
        XCTAssertEqual(q.quit(app("com.example.calc")), .requested)
        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(calculator.activateCalls, 0)
        scheduled[0]()
        XCTAssertEqual(calculator.activateCalls, 1)
    }

    func testOnlyInstancesWithSentRequestsAreActivated() {
        let unsent = FakeApplication("com.example.calc", accepts: false)
        let sent = FakeApplication("com.example.calc")
        var scheduled: [@MainActor () -> Void] = []
        let q = quitter([unsent, sent]) { scheduled.append($0) }
        XCTAssertEqual(q.quit(app("com.example.calc")), .requested)
        XCTAssertEqual(unsent.activateCalls, 0)
        XCTAssertEqual(sent.activateCalls, 0)
        XCTAssertEqual(scheduled.count, 1)
        scheduled[0]()
        XCTAssertEqual(unsent.activateCalls, 0)
        XCTAssertEqual(sent.activateCalls, 1)
    }

    func testApplicationThatExitsDuringDelayIsNotActivated() {
        let calculator = FakeApplication("com.example.calc")
        var scheduled: [@MainActor () -> Void] = []
        let q = quitter([calculator]) { scheduled.append($0) }
        XCTAssertEqual(q.quit(app("com.example.calc")), .requested)
        calculator.isTerminated = true
        scheduled[0]()
        XCTAssertEqual(calculator.activateCalls, 0)
    }

    func testApplicationWithoutPromptIsNotActivated() {
        let stubborn = FakeApplication("com.example.calc")
        var scheduled: [@MainActor () -> Void] = []
        let q = quitter([stubborn], schedule: { scheduled.append($0) }, promptDetection: .notDetected)
        XCTAssertEqual(q.quit(app("com.example.calc")), .requested)
        scheduled[0]()
        XCTAssertEqual(stubborn.activateCalls, 0)
    }

    func testApplicationWithPromptIsActivated() {
        let calculator = FakeApplication("com.example.calc")
        var scheduled: [@MainActor () -> Void] = []
        let q = quitter([calculator], schedule: { scheduled.append($0) }, promptDetection: .detected)
        XCTAssertEqual(q.quit(app("com.example.calc")), .requested)
        scheduled[0]()
        XCTAssertEqual(calculator.activateCalls, 1)
    }

    func testMissingAccessibilityPermissionFallsBackToPreviousBehavior() {
        let calculator = FakeApplication("com.example.calc")
        var scheduled: [@MainActor () -> Void] = []
        let q = quitter([calculator], schedule: { scheduled.append($0) }, promptDetection: .unavailable)
        XCTAssertEqual(q.quit(app("com.example.calc")), .requested)
        scheduled[0]()
        XCTAssertEqual(calculator.activateCalls, 1)
    }

    func testActivationPolicyRequiresRunningApplicationAndPromptOrFallback() {
        XCTAssertEqual(ApplicationQuitActivationPolicy.delay, .milliseconds(750))
        XCTAssertTrue(ApplicationQuitActivationPolicy.shouldActivate(isTerminated: false, promptDetection: .detected))
        XCTAssertTrue(ApplicationQuitActivationPolicy.shouldActivate(isTerminated: false, promptDetection: .unavailable))
        XCTAssertFalse(ApplicationQuitActivationPolicy.shouldActivate(isTerminated: false, promptDetection: .notDetected))
        XCTAssertFalse(ApplicationQuitActivationPolicy.shouldActivate(isTerminated: true, promptDetection: .detected))
    }

    func testEveryInstanceWithSameBundleIdentifierIsTerminated() {
        let first = FakeApplication("com.example.calc")
        let second = FakeApplication("com.example.calc")
        XCTAssertEqual(quitter([first, second]).quit(app("com.example.calc")), .requested)
        XCTAssertEqual(first.terminateCalls, 1)
        XCTAssertEqual(second.terminateCalls, 1)
    }

    func testOneAcceptedInstanceIsEnoughForRequested() {
        let refusing = FakeApplication("com.example.calc", accepts: false)
        let accepting = FakeApplication("com.example.calc")
        XCTAssertEqual(quitter([refusing, accepting]).quit(app("com.example.calc")), .requested)
        XCTAssertEqual(refusing.terminateCalls, 1)
        XCTAssertEqual(accepting.terminateCalls, 1)
    }

    func testStoreShowsQuitOnlyForRunningItems() {
        let store = DockStore(persistence: ProfilePersistence(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("profiles.json")))
        store.applicationQuitter = quitter([])
        let item = app("com.example.calc")
        XCTAssertFalse(store.canQuitApplication(item))
        store.runningItems = [item]
        XCTAssertTrue(store.canQuitApplication(item))
        let finder = app("com.apple.finder")
        store.runningItems = [finder]
        XCTAssertFalse(store.canQuitApplication(finder))
    }

    func testStoreDoesNotClaimTerminationAfterRequest() {
        let store = DockStore(persistence: ProfilePersistence(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("profiles.json")))
        let calculator = FakeApplication("com.example.calc")
        store.applicationQuitter = quitter([calculator])
        let item = app("com.example.calc")
        store.runningItems = [item]
        store.quitApplication(item)
        XCTAssertEqual(calculator.terminateCalls, 1)
        XCTAssertTrue(store.status.contains("要求"))
        XCTAssertEqual(store.runningItems, [item])
        XCTAssertNil(store.errorMessage)
    }

    func testStoreReportsRejectedRequest() {
        let store = DockStore(persistence: ProfilePersistence(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("profiles.json")))
        store.applicationQuitter = quitter([FakeApplication("com.example.calc", accepts: false)])
        let item = app("com.example.calc")
        store.runningItems = [item]
        store.quitApplication(item)
        XCTAssertNotNil(store.errorMessage)
    }

    func testForceQuitCallsForceTerminateOnly() {
        let calculator = FakeApplication("com.example.calc")
        XCTAssertEqual(quitter([calculator]).forceQuit(app("com.example.calc")), .requested)
        XCTAssertEqual(calculator.forceTerminateCalls, 1)
        XCTAssertEqual(calculator.terminateCalls, 0)
        XCTAssertEqual(calculator.activateCalls, 0)
    }

    func testNormalQuitDoesNotForceTerminate() {
        let calculator = FakeApplication("com.example.calc")
        _ = quitter([calculator]).quit(app("com.example.calc"))
        XCTAssertEqual(calculator.forceTerminateCalls, 0)
    }

    func testForceQuitSkipsFinderSelfAndOtherApplications() {
        let finder = FakeApplication("com.apple.finder")
        let other = FakeApplication("com.example.other")
        let q = quitter([finder, other])
        XCTAssertEqual(q.forceQuit(app("com.apple.finder")), .notQuittable)
        XCTAssertEqual(q.forceQuit(app("com.example.calc")), .notRunning)
        XCTAssertEqual(finder.forceTerminateCalls + other.forceTerminateCalls, 0)
    }

    func testForceQuitReportsRejection() {
        let stubborn = FakeApplication("com.example.calc", accepts: false)
        XCTAssertEqual(quitter([stubborn]).forceQuit(app("com.example.calc")), .rejected)
    }

    func testForceQuitReachesEveryInstance() {
        let first = FakeApplication("com.example.calc")
        let second = FakeApplication("com.example.calc")
        XCTAssertEqual(quitter([first, second]).forceQuit(app("com.example.calc")), .requested)
        XCTAssertEqual(first.forceTerminateCalls + second.forceTerminateCalls, 2)
    }

    private func store(_ apps: [FakeApplication]) -> DockStore {
        let store = DockStore(persistence: ProfilePersistence(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("profiles.json")))
        store.applicationQuitter = quitter(apps)
        return store
    }

    func testStoreForceQuitDoesNothingWhenConfirmationIsDeclined() {
        let calculator = FakeApplication("com.example.calc")
        let store = store([calculator])
        store.confirmForceQuit = { _ in false }
        let item = app("com.example.calc")
        store.runningItems = [item]
        store.forceQuitApplication(item)
        XCTAssertEqual(calculator.forceTerminateCalls, 0)
        XCTAssertNil(store.errorMessage)
    }

    func testStoreForceQuitRunsAfterConfirmation() {
        let calculator = FakeApplication("com.example.calc")
        let store = store([calculator])
        var asked: [String] = []
        store.confirmForceQuit = { asked.append($0.name); return true }
        let item = app("com.example.calc")
        store.runningItems = [item]
        store.forceQuitApplication(item)
        XCTAssertEqual(asked, ["com.example.calc"])
        XCTAssertEqual(calculator.forceTerminateCalls, 1)
        XCTAssertEqual(calculator.terminateCalls, 0)
        XCTAssertTrue(store.status.contains("強制終了"))
        XCTAssertNil(store.errorMessage)
    }

    func testStoreForceQuitSkipsConfirmationForNonRunningItems() {
        let store = store([])
        var asked = 0
        store.confirmForceQuit = { _ in asked += 1; return true }
        store.forceQuitApplication(app("com.example.calc"))
        XCTAssertEqual(asked, 0)
    }

    func testStoreReportsRejectedForceQuit() {
        let store = store([FakeApplication("com.example.calc", accepts: false)])
        store.confirmForceQuit = { _ in true }
        let item = app("com.example.calc")
        store.runningItems = [item]
        store.forceQuitApplication(item)
        XCTAssertNotNil(store.errorMessage)
    }

    func testConfirmationTextWarnsAboutUnsavedData() {
        XCTAssertTrue(ForceQuitConfirmation.informativeText.contains("未保存"))
    }

    func testStoreNeverOffersOrRunsForceQuitForFinder() {
        let finder = FakeApplication("com.apple.finder")
        let store = store([finder])
        var asked = 0
        store.confirmForceQuit = { _ in asked += 1; return true }
        let item = app("com.apple.finder")
        store.runningItems = [item]
        XCTAssertFalse(store.canQuitApplication(item))
        store.forceQuitApplication(item)
        XCTAssertEqual(asked, 0)
        XCTAssertEqual(finder.forceTerminateCalls + finder.terminateCalls, 0)
    }
}
