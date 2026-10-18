import XCTest
@testable import DockStudio

private final class FakeApplication: QuittableApplication {
    let bundleIdentifier: String?
    var isTerminated: Bool
    let accepts: Bool
    private(set) var terminateCalls = 0
    init(_ id: String, isTerminated: Bool = false, accepts: Bool = true) {
        bundleIdentifier = id; self.isTerminated = isTerminated; self.accepts = accepts
    }
    func terminate() -> Bool { terminateCalls += 1; return accepts }
}

@MainActor
final class ApplicationQuitTests: XCTestCase {
    private func quitter(_ apps: [FakeApplication]) -> ApplicationQuitter {
        ApplicationQuitter(runningApplications: { id in apps.filter { $0.bundleIdentifier == id } },
                           excludedBundleIdentifiers: ["com.apple.finder", "com.example.self"])
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
}
