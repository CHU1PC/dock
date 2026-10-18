import AppKit
import ApplicationServices

struct AttentionFrameSample: Equatable {
    let bundleIdentifier: String
    let frame: CGRect
}

enum AttentionBouncePolicy {
    static let minimumAmplitude: CGFloat = 18
    static let maximumPeerMovement: CGFloat = 4
    static let minimumInterval: TimeInterval = 10
    static let launchSuppressionInterval: TimeInterval = 30
    static let clearAfter: TimeInterval = 1.2

    static func isBounce(frames: [CGRect], peerMoved: Bool) -> Bool {
        guard frames.count >= 5 else { return false }
        let horizontal = hasRepeatedMovement(frames.map { $0.origin.x }, dimensions: frames.map(\.width))
        let vertical = hasRepeatedMovement(frames.map { $0.origin.y }, dimensions: frames.map(\.height))
        return !peerMoved && (horizontal || vertical)
    }

    private static func hasRepeatedMovement(_ values: [CGFloat], dimensions: [CGFloat]) -> Bool {
        guard dimensions.allSatisfy({ abs($0 - dimensions[0]) <= 4 }) else { return false }
        let amplitude = (values.max() ?? 0) - (values.min() ?? 0)
        guard amplitude >= minimumAmplitude else { return false }
        var reversals = 0
        var previousDirection = 0
        for pair in zip(values, values.dropFirst()) {
            let delta = pair.1 - pair.0
            guard abs(delta) >= 4 else { continue }
            let direction = delta > 0 ? 1 : -1
            if previousDirection != 0, direction != previousDirection { reversals += 1 }
            previousDirection = direction
        }
        return reversals >= 2
    }

    static func shouldDisplay(isBounce: Bool, accessibilityTrusted: Bool, isObservable: Bool,
                              launchedAt: Date?, lastDisplayedAt: Date?, now: Date,
                              suppressForFocus: Bool = false) -> Bool {
        guard isBounce, accessibilityTrusted, isObservable else { return false }
        guard !suppressForFocus else { return false }
        if let launchedAt, now.timeIntervalSince(launchedAt) < launchSuppressionInterval { return false }
        if let lastDisplayedAt, now.timeIntervalSince(lastDisplayedAt) < minimumInterval { return false }
        return true
    }
}

@MainActor
final class AttentionBounceMonitor {
    private let onChange: (Set<String>) -> Void
    private let focusStatus: AttentionBounceFocusStatus
    private var timer: Timer?
    private var framesByBundle: [String: [CGRect]] = [:]
    private var lastMovementAt: [String: Date] = [:]
    private var lastDisplayedAt: [String: Date] = [:]
    private var launchedAt: [String: Date] = [:]
    private var displayed: Set<String> = []
    private var previousFrames: [String: CGRect] = [:]

    init(focusStatus: AttentionBounceFocusStatus = AttentionBounceFocusStatus(), onChange: @escaping (Set<String>) -> Void) {
        self.focusStatus = focusStatus
        self.onChange = onChange
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleIdentifier = app.bundleIdentifier, let launchDate = app.launchDate else { continue }
            launchedAt[bundleIdentifier] = launchDate
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(applicationLaunched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    }

    deinit {
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func start() {
        guard timer == nil else { return }
        focusStatus.requestAuthorizationIfNeeded()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        framesByBundle.removeAll()
        lastMovementAt.removeAll()
        previousFrames.removeAll()
        if !displayed.isEmpty {
            displayed.removeAll()
            onChange(displayed)
        }
    }

    @objc private func applicationLaunched(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleIdentifier = app.bundleIdentifier else { return }
        launchedAt[bundleIdentifier] = Date()
    }

    private func sample() {
        guard AXIsProcessTrusted() else { stop(); return }
        let samples = Self.dockSamples()
        guard !samples.isEmpty else { stop(); return }
        let runningIdentifiers = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let now = Date()
        let suppressForFocus = focusStatus.shouldSuppressBounce
        var nextDisplayed = displayed
        if suppressForFocus { nextDisplayed.removeAll() }
        for sample in samples {
            guard runningIdentifiers.contains(sample.bundleIdentifier) else { continue }
            var history = framesByBundle[sample.bundleIdentifier, default: []]
            history.append(sample.frame)
            if history.count > 7 { history.removeFirst(history.count - 7) }
            framesByBundle[sample.bundleIdentifier] = history
            let peerMoved = samples.contains { peer in
                peer.bundleIdentifier != sample.bundleIdentifier
                    && previousFrames[peer.bundleIdentifier].map { oldFrame in
                        let movedHorizontally = abs(peer.frame.origin.x - oldFrame.origin.x) > AttentionBouncePolicy.maximumPeerMovement
                        let movedVertically = abs(peer.frame.origin.y - oldFrame.origin.y) > AttentionBouncePolicy.maximumPeerMovement
                        return movedHorizontally || movedVertically
                    } == true
            }
            let bouncing = AttentionBouncePolicy.isBounce(frames: history, peerMoved: peerMoved)
            if bouncing {
                lastMovementAt[sample.bundleIdentifier] = now
                if displayed.contains(sample.bundleIdentifier) { continue }
                if AttentionBouncePolicy.shouldDisplay(isBounce: true, accessibilityTrusted: true,
                                                       isObservable: true,
                                                       launchedAt: launchedAt[sample.bundleIdentifier],
                                                       lastDisplayedAt: lastDisplayedAt[sample.bundleIdentifier], now: now,
                                                       suppressForFocus: suppressForFocus) {
                    nextDisplayed.insert(sample.bundleIdentifier)
                    lastDisplayedAt[sample.bundleIdentifier] = now
                }
            }
        }
        previousFrames = Dictionary(uniqueKeysWithValues: samples.map { ($0.bundleIdentifier, $0.frame) })
        for identifier in displayed where now.timeIntervalSince(lastMovementAt[identifier] ?? .distantPast) > AttentionBouncePolicy.clearAfter {
            nextDisplayed.remove(identifier)
        }
        if nextDisplayed != displayed {
            displayed = nextDisplayed
            onChange(displayed)
        }
    }

    private static func dockSamples() -> [AttentionFrameSample] {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return [] }
        let root = AXUIElementCreateApplication(dock.processIdentifier)
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return [] }
        var result: [AttentionFrameSample] = []
        collectSamples(from: children, depth: 0, into: &result)
        return result
    }

    private static func collectSamples(from elements: [AXUIElement], depth: Int, into result: inout [AttentionFrameSample]) {
        guard depth < 5 else { return }
        for element in elements {
            if let url = attribute(element, "AXURL") as? URL,
               let bundleIdentifier = Bundle(url: url.standardizedFileURL)?.bundleIdentifier,
               let frame = frame(of: element) {
                result.append(AttentionFrameSample(bundleIdentifier: bundleIdentifier, frame: frame))
            }
            var childrenValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
               let children = childrenValue as? [AXUIElement] {
                collectSamples(from: children, depth: depth + 1, into: &result)
            }
        }
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionReference = attribute(element, kAXPositionAttribute as String),
              let sizeReference = attribute(element, kAXSizeAttribute as String),
              CFGetTypeID(positionReference) == AXValueGetTypeID(),
              CFGetTypeID(sizeReference) == AXValueGetTypeID() else { return nil }
        let positionValue = positionReference as! AXValue
        let sizeValue = sizeReference as! AXValue
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &origin), AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }
}
