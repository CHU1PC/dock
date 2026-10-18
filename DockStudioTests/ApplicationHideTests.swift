import XCTest
@testable import DockStudio

private final class FakeHideable: HideableApplication {
    let bundleIdentifier: String?
    var isTerminated: Bool
    var isHidden: Bool
    let accepts: Bool
    var hidesImmediately = true
    private(set) var hideCalls = 0
    private(set) var unhideCalls = 0
    init(_ id: String, isHidden: Bool = false, isTerminated: Bool = false, accepts: Bool = true) {
        bundleIdentifier = id; self.isHidden = isHidden; self.isTerminated = isTerminated; self.accepts = accepts
    }
    func hide() -> Bool { hideCalls += 1; if accepts && hidesImmediately { isHidden = true }; return accepts }
    func unhide() -> Bool { unhideCalls += 1; if accepts { isHidden = false }; return accepts }
}

@MainActor
final class ApplicationHideTests: XCTestCase {
    private func hider(_ apps: [FakeHideable]) -> ApplicationHider {
        ApplicationHider(runningApplications: { id in apps.filter { $0.bundleIdentifier == id } },
                         excludedBundleIdentifiers: ["com.example.self"])
    }

    private func app(_ id: String) -> DockItem {
        DockItem(name: id, kind: .application, target: nil, bundleIdentifier: id)
    }

    func testVisibleApplicationIsHidden() {
        let calc = FakeHideable("com.example.calc")
        XCTAssertEqual(hider([calc]).toggle(app("com.example.calc")), .hidden)
        XCTAssertEqual(calc.hideCalls, 1)
        XCTAssertTrue(calc.isHidden)
    }

    func testHiddenApplicationIsShown() {
        let calc = FakeHideable("com.example.calc", isHidden: true)
        XCTAssertEqual(hider([calc]).toggle(app("com.example.calc")), .shown)
        XCTAssertEqual(calc.unhideCalls, 1)
        XCTAssertEqual(calc.hideCalls, 0)
    }

    func testOtherApplicationsAreNotHidden() {
        let calc = FakeHideable("com.example.calc")
        let other = FakeHideable("com.example.other")
        _ = hider([calc, other]).toggle(app("com.example.calc"))
        XCTAssertEqual(other.hideCalls, 0)
        XCTAssertEqual(other.unhideCalls, 0)
        XCTAssertFalse(other.isHidden)
    }

    func testAllInstancesOfSameBundleAreHidden() {
        let first = FakeHideable("com.example.calc")
        let second = FakeHideable("com.example.calc")
        XCTAssertEqual(hider([first, second]).toggle(app("com.example.calc")), .hidden)
        XCTAssertEqual(first.hideCalls, 1)
        XCTAssertEqual(second.hideCalls, 1)
    }

    func testPartiallyHiddenApplicationCountsAsVisible() {
        let first = FakeHideable("com.example.calc", isHidden: true)
        let second = FakeHideable("com.example.calc")
        let h = hider([first, second])
        XCTAssertEqual(h.visibility(of: app("com.example.calc")), .visible)
        XCTAssertEqual(h.toggle(app("com.example.calc")), .hidden)
        XCTAssertEqual(first.hideCalls, 0)
        XCTAssertEqual(second.hideCalls, 1)
    }

    func testTerminatedApplicationIsNotRunning() {
        let gone = FakeHideable("com.example.calc", isTerminated: true)
        let h = hider([gone])
        XCTAssertNil(h.visibility(of: app("com.example.calc")))
        XCTAssertEqual(h.toggle(app("com.example.calc")), .notRunning)
        XCTAssertEqual(gone.hideCalls, 0)
    }

    func testSelfAndNonApplicationItemsAreNotHideable() {
        let own = FakeHideable("com.example.self")
        let calc = FakeHideable("com.example.calc")
        let folder = DockItem(name: "f", kind: .folder, target: nil, bundleIdentifier: "com.example.calc")
        let h = hider([own, calc])
        XCTAssertEqual(h.toggle(app("com.example.self")), .notHideable)
        XCTAssertEqual(h.toggle(folder), .notHideable)
        XCTAssertNil(h.visibility(of: folder))
        XCTAssertEqual(own.hideCalls + calc.hideCalls, 0)
    }

    func testFalseReturnValueIsNotTreatedAsFailure() {
        let calc = FakeHideable("com.example.calc", accepts: false)
        XCTAssertEqual(hider([calc]).toggle(app("com.example.calc")), .hidden)
        XCTAssertEqual(calc.hideCalls, 1)
    }

    private func makeStore() -> DockStore {
        DockStore(persistence: ProfilePersistence(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("profiles.json")))
    }

    func testStoreOffersVisibilityOnlyForRunningItems() {
        let store = makeStore()
        let calc = FakeHideable("com.example.calc")
        store.applicationHider = hider([calc])
        let item = app("com.example.calc")
        XCTAssertNil(store.applicationVisibility(item))
        store.runningItems = [item]
        XCTAssertEqual(store.applicationVisibility(item), .visible)
        store.runningItems = []
        XCTAssertNil(store.applicationVisibility(item))
    }

    func testStoreTogglesAndReportsStatus() {
        let store = makeStore()
        let calc = FakeHideable("com.example.calc")
        store.applicationHider = hider([calc])
        let item = app("com.example.calc")
        store.runningItems = [item]
        store.toggleApplicationVisibility(item)
        XCTAssertTrue(calc.isHidden)
        XCTAssertTrue(store.status.contains("隠しました"))
        store.toggleApplicationVisibility(item)
        XCTAssertFalse(calc.isHidden)
        XCTAssertTrue(store.status.contains("表示しました"))
        XCTAssertNil(store.errorMessage)
    }

    func testStoreShowsFalseReturnAndLateStateWithoutError() {
        let store = makeStore()
        let calc = FakeHideable("com.example.calc", accepts: false)
        store.applicationHider = hider([calc])
        let item = app("com.example.calc")
        store.runningItems = [item]
        store.toggleApplicationVisibility(item)
        XCTAssertNil(store.errorMessage)
        XCTAssertTrue(store.status.contains("隠しました"))
    }

    func testMenuStateFollowsRefreshAfterHiddenStateChanges() {
        let store = makeStore()
        let calc = FakeHideable("com.example.calc")
        store.applicationHider = hider([calc])
        let item = app("com.example.calc")
        store.runningItems = [item]
        store.refreshHiddenApplications()
        XCTAssertEqual(store.applicationVisibility(item), .visible)
        calc.isHidden = true
        XCTAssertEqual(store.applicationVisibility(item), .visible)
        store.refreshHiddenApplications()
        XCTAssertEqual(store.applicationVisibility(item), .hidden)
        calc.isHidden = false
        store.refreshHiddenApplications()
        XCTAssertEqual(store.applicationVisibility(item), .visible)
    }
}
