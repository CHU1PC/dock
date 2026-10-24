import XCTest
@testable import DockStudio

@MainActor
final class HoverPerformanceTests: XCTestCase {
    private func appItems(limit: Int) -> [DockItem] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: "/Applications")) ?? []
        return names.filter { $0.hasSuffix(".app") }.sorted().prefix(limit).map { name in
            DockItem(name: name, kind: .application,
                     target: URL(fileURLWithPath: "/Applications/\(name)/").absoluteString)
        }
    }

    private func makeStore(pinned: Int, running: Int) -> DockStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = DockStore(persistence: ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json")))
        var candidate = store.document
        let activeIndex = candidate.profiles.firstIndex { $0.id == candidate.activeProfileID }!
        candidate.profiles[activeIndex].items = appItems(limit: pinned)
        candidate.settings.showRunningApps = true
        XCTAssertTrue(store.commit(candidate))
        store.runningItems = appItems(limit: 54).suffix(running).map { var copy = $0; copy.id = UUID(); return copy }
        return store
    }

    private func milliseconds(iterations: Int, _ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations { body() }
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6 / Double(iterations)
    }

    /// DockBar.body が1回のホバーで呼ぶ純粋な計算を、同じ呼び出し回数で再現する。
    private func hoverRecompute(_ store: DockStore, hoveredIndex: Int) {
        let layout = store.displayedLayout
        let running = Set(store.runningItems.compactMap(\.applicationIdentity))
        let iconSize = DockMetrics.effectiveIconSize(for: store, availableLength: 1400)
        for _ in 0..<2 {
            _ = DockMetrics.backdropLength(for: store, iconSize: iconSize, axisPadding: 5, hoveredIndex: hoveredIndex,
                                           magnificationScale: 1.8,
                                           windowLength: DockMetrics.length(for: store, magnificationEnabled: true, iconSize: iconSize))
            _ = DockMetrics.backdropThickness(for: store)
        }
        _ = DockMetrics.length(for: store)
        for item in layout.items {
            _ = item.applicationIdentity.map(running.contains)
            _ = item.applicationIdentity
            _ = DockMetrics.effectiveIconSize(for: store, availableLength: 1400)
        }
    }

    func testReportHoverRecomputeCost() {
        let store = makeStore(pinned: 20, running: 30)
        let items = store.displayedItems
        print("HOVERPERF items=\(items.count) running=\(store.runningItems.count)")
        let identity = milliseconds(iterations: 2000) { _ = items[0].applicationIdentity }
        let layout = milliseconds(iterations: 200) { _ = store.displayedLayout }
        let hover = milliseconds(iterations: 50) { hoverRecompute(store, hoveredIndex: 3) }
        print("HOVERPERF identity_ms=\(identity) displayedLayout_ms=\(layout) hoverRecompute_ms=\(hover)")
    }

    func testLayoutCacheReusesValueWhileInputsAndLifetimeHold() {
        var cache = DisplayedLayoutCache()
        let key = DisplayedLayoutCache.Key(pinned: [], running: [], recent: [], finderEntryEnabled: false,
                                           showRunningApps: false, showRecentApps: false, arrangement: .free)
        let start = Date(timeIntervalSince1970: 1000)
        var computed = 0
        let compute = { () -> DockSectionLayoutResult in computed += 1; return DockSectionLayoutResult(items: [], dividerBefore: []) }
        _ = cache.value(for: key, now: start, compute: compute)
        _ = cache.value(for: key, now: start.addingTimeInterval(DisplayedLayoutCache.lifetime - 0.01), compute: compute)
        XCTAssertEqual(computed, 1)
        _ = cache.value(for: key, now: start.addingTimeInterval(DisplayedLayoutCache.lifetime), compute: compute)
        XCTAssertEqual(computed, 2)
    }

    func testLayoutCacheRecomputesWhenInputChanges() {
        var cache = DisplayedLayoutCache()
        var key = DisplayedLayoutCache.Key(pinned: [], running: [], recent: [], finderEntryEnabled: false,
                                           showRunningApps: false, showRecentApps: false, arrangement: .free)
        var computed = 0
        let compute = { () -> DockSectionLayoutResult in computed += 1; return DockSectionLayoutResult(items: [], dividerBefore: []) }
        _ = cache.value(for: key, now: .now, compute: compute)
        key = DisplayedLayoutCache.Key(pinned: [DockItem(name: "A", kind: .folder)], running: [], recent: [],
                                       finderEntryEnabled: false, showRunningApps: false, showRecentApps: false,
                                       arrangement: .free)
        _ = cache.value(for: key, now: .now, compute: compute)
        XCTAssertEqual(computed, 2)
    }

    func testStoreLayoutFollowsRunningAppsChange() {
        let store = makeStore(pinned: 2, running: 4)
        let before = store.displayedItems.count
        store.runningItems = []
        XCTAssertLessThan(store.displayedItems.count, before)
    }

    func testIdentityCacheResolvesOncePerKeyWithinLifetime() {
        let cache = ApplicationIdentityCache()
        let start = Date(timeIntervalSince1970: 1000)
        var resolved = 0
        let resolve = { () -> String? in resolved += 1; return "bundle:x" }
        XCTAssertEqual(cache.identity(target: "file:///a/", bundleIdentifier: nil, now: start, resolve: resolve), "bundle:x")
        XCTAssertEqual(cache.identity(target: "file:///a/", bundleIdentifier: nil, now: start.addingTimeInterval(0.5), resolve: resolve), "bundle:x")
        XCTAssertEqual(resolved, 1)
        _ = cache.identity(target: "file:///b/", bundleIdentifier: nil, now: start, resolve: resolve)
        XCTAssertEqual(resolved, 2)
        _ = cache.identity(target: "file:///a/", bundleIdentifier: nil, now: start.addingTimeInterval(ApplicationIdentityCache.lifetime), resolve: resolve)
        XCTAssertEqual(resolved, 3)
    }
}
