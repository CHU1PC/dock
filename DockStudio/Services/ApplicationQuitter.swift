import AppKit

protocol QuittableApplication {
    var bundleIdentifier: String? { get }
    var bundleURL: URL? { get }
    var isTerminated: Bool { get }
    func terminate() -> Bool
    func activate()
    func forceTerminate() -> Bool
}

extension NSRunningApplication: QuittableApplication {
    func activate() {
        guard let bundleURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration)
    }
}

enum ApplicationQuitActivationPolicy {
    static let delay = Duration.milliseconds(750)

    static func shouldActivate(requestWasSent: Bool, isTerminated: Bool) -> Bool {
        requestWasSent && !isTerminated
    }
}

enum ApplicationQuitOutcome: Equatable {
    case requested
    case notRunning
    case notQuittable
    case rejected
}

struct ApplicationQuitter {
    var runningApplications: (String) -> [any QuittableApplication]
    var excludedBundleIdentifiers: Set<String>
    var scheduleActivation: (@escaping @MainActor () -> Void) -> Void = { action in
        Task { @MainActor in
            try? await Task.sleep(for: ApplicationQuitActivationPolicy.delay)
            action()
        }
    }

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
        request(item) {
            let application = $0
            guard application.terminate() else { return false }
            scheduleActivation {
                guard ApplicationQuitActivationPolicy.shouldActivate(
                    requestWasSent: true,
                    isTerminated: application.isTerminated
                ) else { return }
                application.activate()
            }
            return true
        }
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
