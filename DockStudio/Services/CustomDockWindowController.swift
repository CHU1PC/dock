import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class DockPanelLayout {
    var vertical = false
    var collapsed = false
    var size = CGSize(width: 220, height: 80)
}

@MainActor
final class CustomDockWindowController {
    private let store: DockStore
    private let panel: NSPanel
    private let layout = DockPanelLayout()
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var visibility = DockVisibilityState()
    private var trackingMenus = 0

    init(store: DockStore) {
        self.store = store
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Dock Studio — Custom Dock"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: PanelDockContent(layout: layout).environment(store))
        refreshRunningApps()
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshRunningApps() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.store.availableDisplays = DisplayOption.current
                self.update()
            }
        })
        for name in [NSMenu.didBeginTrackingNotification, NSMenu.didEndTrackingNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.trackingMenus = max(0, self.trackingMenus + (notification.name == NSMenu.didBeginTrackingNotification ? 1 : -1))
                    self.updateAutoHide()
                }
            })
        }
        timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateAutoHide() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        observeChanges()
    }

    deinit {
        timer?.invalidate()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func observeChanges() {
        withObservationTracking { update() } onChange: { [weak self] in
            Task { @MainActor in self?.observeChanges() }
        }
    }

    private var selectedScreen: NSScreen? {
        let screens = NSScreen.screens
        let selectedID = DisplayOption.preferredID(selectedID: store.document.settings.displayID,
                                                  availableIDs: DisplayOption.current.map(\.id))
        return screens.first {
            $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 == selectedID
        } ?? screens.first
    }

    private func updateVisibility() {
        visibility.update(visible: store.isDockEffectivelyVisible,
                          autoHide: store.document.settings.autoHide,
                          hovering: panel.isVisible && panel.frame.insetBy(dx: -24, dy: -24).contains(NSEvent.mouseLocation),
                          interacting: trackingMenus > 0 || !store.activePopoverTokens.isEmpty, now: .now)
    }

    private func update() {
        updateVisibility()
        guard store.isDockEffectivelyVisible, let screen = selectedScreen else {
            panel.orderOut(nil)
            return
        }
        let visible = screen.visibleFrame.insetBy(dx: 10, dy: 10)
        let vertical = store.document.settings.position != .bottom
        let length = min(DockMetrics.length(for: store), vertical ? visible.height : visible.width)
        let thickness = DockMetrics.thickness(for: store)
        var frame = NSRect(origin: .zero, size: vertical ? NSSize(width: thickness, height: length) : NSSize(width: length, height: thickness))
        switch store.document.settings.position {
        case .bottom:
            if visibility.isCollapsed { frame.size = NSSize(width: 100, height: 8) }
            frame.origin = NSPoint(x: visible.midX - frame.width / 2, y: visible.minY)
        case .left:
            if visibility.isCollapsed { frame.size = NSSize(width: 8, height: 100) }
            frame.origin = NSPoint(x: visible.minX, y: visible.midY - frame.height / 2)
        case .right:
            if visibility.isCollapsed { frame.size = NSSize(width: 8, height: 100) }
            frame.origin = NSPoint(x: visible.maxX - frame.width, y: visible.midY - frame.height / 2)
        }
        layout.vertical = vertical
        layout.collapsed = visibility.isCollapsed
        layout.size = frame.size
        panel.setFrame(frame, display: true)
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func updateAutoHide() {
        let oldValue = visibility.isCollapsed
        updateVisibility()
        if oldValue != visibility.isCollapsed { update() }
    }

    private func refreshRunningApps() {
        let previous = store.runningItems
        var seen: Set<String> = []
        store.runningItems = NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, app.bundleIdentifier != Bundle.main.bundleIdentifier,
                  let url = app.bundleURL else { return nil }
            let candidate = DockItem(name: app.localizedName ?? url.deletingPathExtension().lastPathComponent,
                                     kind: .application, target: url.absoluteString, bundleIdentifier: app.bundleIdentifier)
            guard let identity = candidate.applicationIdentity, seen.insert(identity).inserted else { return nil }
            return previous.first(where: { $0.applicationIdentity == identity }) ?? candidate
        }
    }
}

private struct PanelDockContent: View {
    @Environment(DockStore.self) private var store
    let layout: DockPanelLayout
    var body: some View {
        ZStack {
            DockBar(vertical: layout.vertical)
                .opacity(layout.collapsed ? 0 : 1)
                .allowsHitTesting(!layout.collapsed)
                .accessibilityHidden(layout.collapsed)
                .contextMenu {
                    Button("Dock を隠す") { store.isDockVisible = false }
                    ForEach(store.document.profiles) { profile in
                        Button(profile.name) { store.activateProfile(profile.id) }
                    }
                }
            if layout.collapsed {
                Capsule().fill(StudioColor.accent.opacity(0.8)).padding(1)
                    .accessibilityLabel("Custom Dock を表示するにはポインタを重ねます")
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }
}
