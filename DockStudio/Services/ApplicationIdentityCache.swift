import Foundation

/// applicationIdentity はバンドルの読み込みを伴うため、短時間だけ結果を使い回す。
final class ApplicationIdentityCache: @unchecked Sendable {
    static let shared = ApplicationIdentityCache()
    static let lifetime: TimeInterval = 1
    static let capacity = 512

    private struct Key: Hashable {
        let target: String?
        let bundleIdentifier: String?
    }

    private let lock = NSLock()
    private var entries: [Key: (identity: String?, resolvedAt: Date)] = [:]

    func identity(target: String?, bundleIdentifier: String?, now: Date = .now,
                  resolve: () -> String?) -> String? {
        let key = Key(target: target, bundleIdentifier: bundleIdentifier)
        lock.lock()
        let cached = entries[key]
        lock.unlock()
        if let cached, now.timeIntervalSince(cached.resolvedAt) < Self.lifetime { return cached.identity }
        let identity = resolve()
        lock.lock()
        if entries.count >= Self.capacity { entries.removeAll() }
        entries[key] = (identity, now)
        lock.unlock()
        return identity
    }
}
