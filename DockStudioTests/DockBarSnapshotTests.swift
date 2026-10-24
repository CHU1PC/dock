import XCTest
@testable import DockStudio

@MainActor
final class DockBarSnapshotTests: XCTestCase {
    private func app(_ name: String) -> DockItem {
        DockItem(name: name, kind: .application, target: "file:///Applications/\(name).app")
    }

    private func store(pinned: [DockItem], arrangement: DockArrangement, showRunning: Bool = false,
                       configure: (inout DockSettings) -> Void = { _ in }) -> DockStore {
        let profile = DockProfile(name: "P", items: pinned)
        var document = DockDocument(profiles: [profile], activeProfileID: profile.id)
        document.settings.arrangement = arrangement
        document.settings.showRunningApps = showRunning
        configure(&document.settings)
        return DockStore(persistence: nil, initial: document)
    }

    private func assertMatchesLayout(_ store: DockStore, file: StaticString = #filePath, line: UInt = #line) {
        let layout = store.displayedLayout
        let snapshot = DockBarSnapshotBuilder.make(store: store)
        let running = Set(store.runningItems.compactMap(\.applicationIdentity))
        XCTAssertEqual(snapshot.items.map(\.id), layout.items.map(\.id), file: file, line: line)
        XCTAssertEqual(snapshot.items.map(\.kind), layout.items.map(\.kind), file: file, line: line)
        XCTAssertEqual(snapshot.items.map(\.title), layout.items.map(\.name), file: file, line: line)
        XCTAssertEqual(Set(snapshot.items.indices.filter { snapshot.items[$0].dividerBefore }),
                       layout.dividerBefore.filter { $0 < layout.items.count }, file: file, line: line)
        XCTAssertEqual(snapshot.items.map(\.isRunning),
                       layout.items.map { $0.applicationIdentity.map(running.contains) == true },
                       file: file, line: line)
        XCTAssertEqual(snapshot.items.map(\.badge),
                       layout.items.map { NotificationBadgeSnapshot.badge(for: $0, in: store.notificationBadges) },
                       file: file, line: line)
        XCTAssertEqual(snapshot.trash.dividerBefore, layout.dividerBefore.contains(layout.items.count), file: file, line: line)
    }

    func testStandardSectionsMatchDisplayedLayoutKindsAndDividers() {
        let folder = DockItem(name: "Folder", kind: .folder, target: "file:///tmp")
        let file = DockItem(name: "File", kind: .file, target: "file:///tmp/a.txt")
        let spacer = DockItem(name: "Spacer", kind: .spacer)
        let store = store(pinned: [folder, app("A"), file, spacer, app("B")], arrangement: .standardSections)
        assertMatchesLayout(store)
        let snapshot = DockBarSnapshotBuilder.make(store: store)
        XCTAssertTrue(snapshot.items.contains { $0.dividerBefore })
        XCTAssertTrue(snapshot.items.contains { $0.kind == .spacer })
    }

    func testFreeArrangementHasNoDividers() {
        let store = store(pinned: [DockItem(name: "Folder", kind: .folder, target: "file:///tmp"), app("A")],
                          arrangement: .free)
        assertMatchesLayout(store)
        XCTAssertFalse(DockBarSnapshotBuilder.make(store: store).items.contains { $0.dividerBefore })
    }

    func testRunningFlagFollowsRunningApplications() {
        let a = app("A")
        let b = app("B")
        let store = store(pinned: [a, b], arrangement: .free)
        store.runningItems = [a]
        let snapshot = DockBarSnapshotBuilder.make(store: store)
        XCTAssertEqual(snapshot.items.map(\.isRunning), [true, false])
        assertMatchesLayout(store)
    }

    func testBadgesAreOnlyOnApplicationsWithMatchingPath() {
        let a = app("A")
        let b = app("B")
        let folder = DockItem(name: "Folder", kind: .folder, target: "file:///Applications/A.app")
        let store = store(pinned: [a, b, folder], arrangement: .free)
        store.notificationBadges = [NotificationBadgeSnapshot.key(for: URL(string: "file:///Applications/A.app")!): "3"]
        let snapshot = DockBarSnapshotBuilder.make(store: store)
        XCTAssertEqual(snapshot.items.map(\.badge), ["3", nil, nil])
        assertMatchesLayout(store)
    }

    func testShownRunningAppsAppearInSnapshotWithRunningFlag() {
        let a = app("A")
        let extra = app("Extra")
        let store = store(pinned: [a], arrangement: .standardSections, showRunning: true)
        store.runningItems = [a, extra]
        let snapshot = DockBarSnapshotBuilder.make(store: store)
        XCTAssertEqual(snapshot.items.map(\.title), ["A", "Extra"])
        XCTAssertEqual(snapshot.items.map(\.isRunning), [true, true])
        assertMatchesLayout(store)
    }

    func testAttentionBounceAndSizeValues() {
        let a = app("A")
        let store = store(pinned: [a], arrangement: .free) { $0.attentionBounce = true; $0.position = .left }
        store.attentionRequestingIdentities = [a.applicationIdentity!]
        let snapshot = DockBarSnapshotBuilder.make(store: store, systemReduceMotion: true)
        XCTAssertEqual(snapshot.items.map(\.isAttentionRequested), [true])
        XCTAssertEqual(snapshot.position, .left)
        XCTAssertEqual(snapshot.iconSize, store.effectiveIconSize)
        XCTAssertTrue(snapshot.reduceMotion)
        XCTAssertEqual(snapshot.appearance, store.appearance)
        XCTAssertEqual(snapshot.trash.state, store.trashState)
    }
}
