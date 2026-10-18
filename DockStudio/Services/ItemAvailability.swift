import AppKit
import Darwin
import Observation

enum ItemAvailability: Equatable, Sendable {
    case available
    case missing
    case volumeNotMounted
    case inaccessible

    var isUnavailable: Bool { self == .missing || self == .volumeNotMounted }
}

struct ItemAvailabilityChecker: Sendable {
    var probe: @Sendable (String) -> Int32 = ItemAvailabilityChecker.statErrno

    static func statErrno(_ path: String) -> Int32 {
        var info = stat()
        return stat(path, &info) == 0 ? 0 : errno
    }

    func check(_ item: DockItem) -> ItemAvailability {
        switch item.kind {
        case .application, .folder, .file: break
        default: return .available
        }
        guard let url = item.targetURL, url.isFileURL else { return .missing }
        let path = url.standardizedFileURL.path
        let code = probe(path)
        switch code {
        case 0:
            return .available
        case ENOENT, ENOTDIR:
            if let mountPoint = Self.volumeMountPoint(of: path), mountPoint != path {
                let mountCode = probe(mountPoint)
                if mountCode == ENOENT || mountCode == ENOTDIR { return .volumeNotMounted }
                if mountCode != 0 { return .inaccessible }
            }
            return .missing
        default:
            return .inaccessible
        }
    }

    static func volumeMountPoint(of path: String) -> String? {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 2, parts[0] == "Volumes" else { return nil }
        return "/Volumes/\(parts[1])"
    }
}

@MainActor
@Observable
final class ItemAvailabilityMonitor {
    private struct Entry {
        let target: String?
        let status: ItemAvailability
    }

    private var entries: [UUID: Entry] = [:]
    @ObservationIgnored private let checker: ItemAvailabilityChecker
    @ObservationIgnored private let allItems: () -> [DockItem]
    @ObservationIgnored private var lastFullRefresh: Date?
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(checker: ItemAvailabilityChecker = .init(), allItems: @escaping () -> [DockItem] = { [] }) {
        self.checker = checker
        self.allItems = allItems
    }

    func status(of item: DockItem) -> ItemAvailability {
        guard let entry = entries[item.id], entry.target == item.target else { return .available }
        return entry.status
    }

    func refresh(_ items: [DockItem]) async {
        let checker = checker
        let results = await Task.detached(priority: .utility) {
            items.map { ($0, checker.check($0)) }
        }.value
        for (item, status) in results { record(item, status) }
    }

    func refreshAll(minInterval: TimeInterval = 0) async {
        let now = Date()
        if let last = lastFullRefresh, now.timeIntervalSince(last) < minInterval { return }
        lastFullRefresh = now
        await refresh(allItems())
    }

    func record(_ item: DockItem, _ status: ItemAvailability) {
        entries[item.id] = Entry(target: item.target, status: status)
    }

    func startObserving() {
        guard observers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        let names: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.didMountNotification),
            (workspace, NSWorkspace.didUnmountNotification),
        ]
        for (center, name) in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.refreshAll() }
            }
            observers.append((center, token))
        }
    }

    func stopObserving() {
        for (center, token) in observers { center.removeObserver(token) }
        observers = []
    }
}
