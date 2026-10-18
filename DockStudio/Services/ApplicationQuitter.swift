import AppKit

protocol QuittableApplication {
    var bundleIdentifier: String? { get }
    var isTerminated: Bool { get }
    func terminate() -> Bool
    func forceTerminate() -> Bool
}

extension NSRunningApplication: QuittableApplication {}

enum ApplicationQuitOutcome: Equatable {
    case requested
    case notRunning
    case notQuittable
    case rejected
}

struct ApplicationQuitter {
    var runningApplications: (String) -> [any QuittableApplication]
    var excludedBundleIdentifiers: Set<String>

    static let live = ApplicationQuitter(
        runningApplications: { NSRunningApplication.runningApplications(withBundleIdentifier: $0) },
        excludedBundleIdentifiers: ["com.apple.finder", Bundle.main.bundleIdentifier].compactMap { $0 }.reduce(into: []) { $0.insert($1) })

    func quittableBundleIdentifier(for item: DockItem) -> String? {
        guard item.kind == .application, let identity = item.applicationIdentity,
              identity.hasPrefix("bundle:") else { return nil }
        let identifier = String(identity.dropFirst("bundle:".count))
        return excludedBundleIdentifiers.contains(identifier) ? nil : identifier
    }

    func quit(_ item: DockItem) -> ApplicationQuitOutcome {
        request(item) { $0.terminate() }
    }

    func forceQuit(_ item: DockItem) -> ApplicationQuitOutcome {
        request(item) { $0.forceTerminate() }
    }

    private func request(_ item: DockItem, _ action: (any QuittableApplication) -> Bool) -> ApplicationQuitOutcome {
        guard let identifier = quittableBundleIdentifier(for: item) else { return .notQuittable }
        let running = runningApplications(identifier).filter { !$0.isTerminated }
        guard !running.isEmpty else { return .notRunning }
        let results = running.map(action)
        return results.contains(true) ? .requested : .rejected
    }
}

enum ForceQuitConfirmation {
    static let informativeText = "未保存の変更は失われます。通常の終了で終わらない場合にだけ使ってください。"
}
