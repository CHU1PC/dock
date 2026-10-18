import AppKit
import Observation
import SwiftUI

struct DisplayOption: Identifiable {
    let id: UInt32
    let name: String

    static func preferredID(selectedID: UInt32?, availableIDs: [UInt32]) -> UInt32? {
        if let selectedID, availableIDs.contains(selectedID) { return selectedID }
        return availableIDs.first
    }

    @MainActor
    static var current: [DisplayOption] {
        NSScreen.screens.compactMap { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return nil }
            return DisplayOption(id: id, name: screen.localizedName)
        }
    }
}

enum DockInteractionGeometry {
    static let panelPadding: CGFloat = 8
    static let bottomGap: CGFloat = 5

    static func panelOrigin(screen: NSRect, available: NSRect, size: NSSize, position: DockPosition) -> NSPoint {
        switch position {
        case .bottom:
            return NSPoint(x: screen.midX - size.width / 2, y: screen.minY + bottomGap - panelPadding)
        case .left: return NSPoint(x: available.minX, y: available.midY - size.height / 2)
        case .right: return NSPoint(x: available.maxX - size.width, y: available.midY - size.height / 2)
        }
    }

    static func reveal(screen: NSRect, panel: NSRect, position: DockPosition) -> NSRect {
        switch position {
        case .bottom:
            return NSRect(x: panel.minX, y: screen.minY, width: panel.width,
                          height: max(8, panel.minY - screen.minY + 16))
        case .left:
            return NSRect(x: screen.minX, y: panel.minY, width: max(8, panel.minX - screen.minX + 16), height: panel.height)
        case .right:
            return NSRect(x: panel.maxX - 16, y: panel.minY,
                          width: max(8, screen.maxX - panel.maxX + 16), height: panel.height)
        }
    }
}

@MainActor
@Observable
final class DockPanelLayout {
    var vertical = false
    var collapsed = false
    var size = CGSize(width: 220, height: 80)
    var position: DockPosition = .bottom
    var reduceMotion = false
    var revealAnimationDuration = DockSettings().revealAnimationDuration
}

@MainActor
private final class DockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
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
    private var pointerMonitor: Any?
    private var localMonitor: Any?
    private var previousApp: NSRunningApplication?

    init(store: DockStore) {
        self.store = store
        panel = DockPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Dock Studio — Custom Dock"
        panel.isFloatingPanel = true
        // 標準 Dock と同じ画面端でも、Custom Dock の操作領域を背面に隠さない。
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: PanelDockContent(layout: layout).environment(store))
        refreshRunningApps()
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                MainActor.assumeIsolated {
                    if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                       let url = app.bundleURL { DockIconRenderer.invalidate(url: url) }
                    self?.refreshRunningApps()
                }
            })
        }
        for center in [NotificationCenter.default, NSWorkspace.shared.notificationCenter] {
            observers.append(center.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.update() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.store.availableDisplays = DisplayOption.current
                self.update()
            }
        })
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: panel, queue: .main) { [weak self] notification in
                MainActor.assumeIsolated {
                    let isKey = notification.name == NSWindow.didBecomeKeyNotification
                    self?.store.isDockPanelKey = isKey
                    if !isKey { self?.previousApp = nil }
                    self?.updateAutoHide()
                }
            })
        }
        for name in [NSMenu.didBeginTrackingNotification, NSMenu.didEndTrackingNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.trackingMenus = max(0, self.trackingMenus + (notification.name == NSMenu.didBeginTrackingNotification ? 1 : -1))
                    self.updateAutoHide()
                }
            })
        }
        pointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateAutoHide(); self?.updatePointerPassThrough() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDown, .keyDown]) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                if event.type == .rightMouseDown, let self, event.window === self.panel {
                    // 非アクティブ時も SwiftUI のメニューにキーボードフォーカスを渡す。
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    self.panel.makeKeyAndOrderFront(nil)
                }
                if event.type == .keyDown {
                    if let self, self.panel.isKeyWindow, self.trackingMenus == 0 {
                        if event.keyCode == 53 { self.leaveKeyboard(); return true }
                    }
                } else { self?.updateAutoHide(); self?.updatePointerPassThrough() }
                return false
            }
            return handled ? nil : event
        }
        observeChanges()
    }

    deinit {
        timer?.invalidate()
        if let pointerMonitor { NSEvent.removeMonitor(pointerMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
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

    private var revealFrame: NSRect {
        DockInteractionGeometry.reveal(screen: selectedScreen?.frame ?? panel.frame, panel: panel.frame,
                                       position: store.document.settings.position)
    }

    private var interactionFrame: NSRect {
        let frame = panel.frame.insetBy(dx: DockInteractionGeometry.panelPadding, dy: DockInteractionGeometry.panelPadding)
        if store.document.settings.position == .bottom {
            let maximum = store.appearance.magnification ? store.appearance.magnificationScale : 1
            return NSRect(x: frame.minX, y: frame.minY, width: frame.width,
                          height: max(store.effectiveIconSize * maximum, 54) + 30)
        }
        let bar = DockMetrics.barThickness(for: store)
        return store.document.settings.position == .left
            ? NSRect(x: frame.minX, y: frame.minY, width: bar, height: frame.height)
            : NSRect(x: frame.maxX - bar, y: frame.minY, width: bar, height: frame.height)
    }

    private var autoHideEnabled: Bool { store.document.settings.autoHide && !NSWorkspace.shared.isVoiceOverEnabled }

    private func updateVisibility() {
        let point = NSEvent.mouseLocation
        visibility.update(visible: store.isDockEffectivelyVisible, autoHide: autoHideEnabled,
                          hovering: panel.isVisible && (revealFrame.contains(point) || (!visibility.isCollapsed && interactionFrame.contains(point))),
                          interacting: trackingMenus > 0 || !store.activePopoverTokens.isEmpty
                            || panel.isKeyWindow || store.dockKeyboardFocusRequested, now: .now)
    }

    private func update() {
        updateVisibility()
        panel.appearance = store.appearance.colorMode.nsAppearance
        if store.dockKeyboardExitRequested {
            store.dockKeyboardExitRequested = false
            leaveKeyboard()
        }
        guard store.isDockEffectivelyVisible, let screen = selectedScreen else {
            if previousApp != nil { leaveKeyboard() }
            timer?.invalidate(); timer = nil
            panel.orderOut(nil)
            return
        }
        let visible = screen.visibleFrame.insetBy(dx: 10, dy: 10)
        let vertical = store.document.settings.position != .bottom
        let padding = DockInteractionGeometry.panelPadding * 2
        let maximumLength = vertical ? visible.height : screen.frame.insetBy(dx: 10, dy: 10).width
        let length = min(DockMetrics.length(for: store) + padding, maximumLength)
        let thickness = DockMetrics.thickness(for: store) + padding + (vertical ? DockMetrics.sideLabelGutter : 0)
        var frame = NSRect(origin: .zero, size: vertical ? NSSize(width: thickness, height: length) : NSSize(width: length, height: thickness))
        frame.origin = DockInteractionGeometry.panelOrigin(screen: screen.frame, available: visible,
                                                           size: frame.size, position: store.document.settings.position)
        layout.position = store.document.settings.position
        layout.reduceMotion = store.appearance.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        layout.revealAnimationDuration = store.effectiveRevealAnimationDuration
        layout.vertical = vertical
        layout.collapsed = visibility.isCollapsed
        layout.size = frame.size
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        if !panel.isVisible { panel.orderFrontRegardless() }
        if store.dockKeyboardFocusRequested {
            store.dockKeyboardFocusRequested = false
            if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                previousApp = front
            }
            NSApplication.shared.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
        updatePointerPassThrough()
        if autoHideEnabled && timer == nil {
            timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateAutoHide(); self?.updatePointerPassThrough() }
            }
            if let timer { RunLoop.main.add(timer, forMode: .common) }
        } else if !autoHideEnabled { timer?.invalidate(); timer = nil }
    }

    private func leaveKeyboard() {
        let app = previousApp
        panel.resignKey()
        if let app, !app.isTerminated { app.activate(from: NSRunningApplication.current) }
    }

    private func updatePointerPassThrough() {
        guard panel.isVisible else { return }
        let inside = !visibility.isCollapsed && interactionFrame.contains(NSEvent.mouseLocation)
        if store.isDockPointerInside != inside { store.isDockPointerInside = inside }
        panel.ignoresMouseEvents = !(visibility.isCollapsed ? revealFrame.contains(NSEvent.mouseLocation) : inside)
            && trackingMenus == 0 && store.activePopoverTokens.isEmpty
    }

    private func updateAutoHide() {
        guard store.isDockEffectivelyVisible else { return }
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
            DockBar(vertical: layout.vertical, isPanel: true)
                .frame(width: layout.vertical ? DockMetrics.barThickness(for: store) : nil)
                .padding(DockInteractionGeometry.panelPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: layout.position == .left ? .leading : layout.position == .right ? .trailing : .center)
                .offset(x: layout.collapsed ? (layout.position == .left ? -layout.size.width : layout.position == .right ? layout.size.width : 0) : 0,
                        y: layout.collapsed && layout.position == .bottom ? layout.size.height : 0)
                .opacity(layout.collapsed ? 0 : 1)
                .animation(layout.reduceMotion || (!layout.collapsed && layout.revealAnimationDuration == 0)
                           ? nil : .easeInOut(duration: layout.collapsed ? 0.22 : layout.revealAnimationDuration),
                           value: layout.collapsed)
                .allowsHitTesting(!layout.collapsed)
                .accessibilityHidden(layout.collapsed)
                .contextMenu {
                    Button("Dock を隠す") { store.isDockVisible = false }
                    Button("キーボードで操作") { store.focusDock() }
                    ForEach(store.document.profiles) { profile in
                        Button(profile.name) { store.activateProfile(profile.id) }
                    }
                }
            if layout.collapsed {
                Color.clear.accessibilityElement(children: .ignore)
                    .accessibilityLabel("Custom Dock を表示")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { store.focusDock() }
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }
}
