import Foundation

/// ホバーのたびに再計算される displayedLayout を、入力が同じ間だけ使い回す。
struct DisplayedLayoutCache {
    struct Key: Equatable {
        let pinned: [DockItem]
        let running: [DockItem]
        let recent: [DockItem]
        let finderEntryEnabled: Bool
        let showRunningApps: Bool
        let showRecentApps: Bool
        let arrangement: DockArrangement
    }

    static let lifetime: TimeInterval = 1

    private var entry: (key: Key, computedAt: Date, value: DockSectionLayoutResult)?

    mutating func value(for key: Key, now: Date, compute: () -> DockSectionLayoutResult) -> DockSectionLayoutResult {
        if let entry, entry.key == key, now.timeIntervalSince(entry.computedAt) < Self.lifetime { return entry.value }
        let value = compute()
        entry = (key, now, value)
        return value
    }
}
