import SwiftUI
import UniformTypeIdentifiers

struct CustomDockPreview: View {
    @Environment(DockStore.self) private var store

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DesktopBackground()
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Custom Dock").font(.system(size: 25, weight: .semibold, design: .rounded))
                        Spacer()
                        Menu {
                            ForEach(store.document.profiles) { profile in
                                Button(profile.name) { store.activateProfile(profile.id) }
                            }
                        } label: {
                            Label(store.activeProfile.name, systemImage: "square.stack.3d.up")
                        }
                        .buttonStyle(.bordered)
                    }
                    Text("アプリとウィジェットを、使う場面ごとにまとめます。")
                        .foregroundStyle(.white.opacity(0.72))
                    if !store.status.isEmpty {
                        Text(store.status).font(.callout).foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Button(store.isDockEffectivelyVisible ? "デスクトップの Dock を隠す" : "デスクトップに Dock を表示") {
                        store.toggleDockVisibility()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if store.document.settings.mode != .native {
                    dockPreview(in: geometry.size)
                } else {
                    ContentUnavailableView("Apple Dock を使用中", systemImage: "dock.rectangle",
                                           description: Text("設定で Custom Dock または両方を選ぶと、ここに表示されます。"))
                }
            }
        }
    }

    private func dockPreview(in size: CGSize) -> some View {
        let vertical = store.document.settings.position != .bottom
        let alignment: Alignment = switch store.document.settings.position {
        case .left: .leading
        case .bottom: .bottom
        case .right: .trailing
        }
        return DockBar(vertical: vertical)
            .environment(store)
            .frame(width: vertical ? 190 : min(size.width - 50, DockMetrics.length(for: store)),
                   height: vertical ? min(size.height - 120, DockMetrics.length(for: store)) : DockMetrics.thickness(for: store))
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

struct DockBar: View {
    @Environment(DockStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var hovered: UUID?
    @FocusState private var focused: UUID?
    @State private var lastFocused: UUID?
    @State private var menuRequest: UUID?
    @State private var keyboardNavigating = false
    @State private var focusTask: Task<Void, Never>?
    @State private var typeAhead = DockTypeAheadBuffer()
    @State private var barSize: CGSize = .zero
    @State private var itemRects: [UUID: CGRect] = [:]
    @State private var dropIndex: Int?
    let vertical: Bool
    var isPanel = false
    var temporaryMagnificationEnabled: Bool?
    private func refreshAvailability() {
        Task { await store.itemAvailability.refreshAll(minInterval: 1) }
    }

    private var motion: Animation? {
        store.appearance.reduceMotion || systemReduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82)
    }

    var body: some View {
        let items = store.displayedItems
        let hoverIndex = DockStore.hoverableItems(items).firstIndex { $0.id == hovered }
        let running = Set(store.runningItems.compactMap(\.applicationIdentity))
        ZStack(alignment: vertical ? .center : .bottom) {
            DockBackdrop(appearance: store.appearance)
                .frame(width: vertical ? DockMetrics.barThickness(for: store, magnificationEnabled: temporaryMagnificationEnabled) : nil,
                       height: vertical ? nil : DockMetrics.barThickness(for: store))
                .shadow(color: .black.opacity(store.appearance.background == .transparent || store.appearance.background == .appleDock ? 0 : 0.18), radius: 4, y: -2)
            ScrollView(vertical ? .vertical : .horizontal) {
                let layout = vertical ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(alignment: .bottom, spacing: 0))
                DockGlassContainer(enabled: store.appearance.iconStyle == .glass) {
                    layout {
                        if items.isEmpty {
                            Label("プロファイルに項目を追加", systemImage: "plus.circle")
                                .font(.callout).foregroundStyle(.secondary).padding(10)
                        }
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            barElement(item, index: index, hoveredIndex: hoverIndex, runningIdentities: running)
                        }
                        MinimizedWindowsDockSection(vertical: vertical, iconSize: store.effectiveIconSize,
                                                    iconStyle: store.appearance.iconStyle,
                                                    controller: store.minimizedWindowController,
                                                    groupedByApplication: store.document.settings.minimizeWindowsIntoAppIcon,
                                                    enabled: isPanel && store.isDockVisible)
                        trashSection(index: items.count, hoveredIndex: hoverIndex)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(minWidth: vertical ? nil : DockMetrics.length(for: store),
                       minHeight: vertical ? DockMetrics.length(for: store) : DockMetrics.thickness(for: store),
                       alignment: vertical ? .center : .bottom)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .coordinateSpace(name: DockDragOutRemoval.space)
        .onGeometryChange(for: CGSize.self, of: \.size) { barSize = $0 }
        .coordinateSpace(name: Self.space)
        .onPreferenceChange(DockItemFrames.self) { itemRects = $0 }
        .overlay { dropIndicator(items: items) }
        .onDrop(of: [.fileURL], delegate: DockDropDelegate(
            store: store, vertical: vertical, frames: items.compactMap { itemRects[$0.id] },
            isMeasured: items.allSatisfy { itemRects[$0.id] != nil }, index: $dropIndex))
        .animation(motion, value: hovered)
        .onChange(of: items.map(\.id)) { old, new in
            hovered = nil
            guard let id = lastFocused, controlActiveState == .key, !new.contains(id),
                  let removedIndex = old.firstIndex(of: id) else { return }
            focus(DockKeyboardNavigation.indexAfterRemoval(at: removedIndex, entries: Self.entries(of: items)), in: items)
        }
        .onChange(of: focused) { if let focused { lastFocused = focused } }
        .onChange(of: hovered) { if hovered != nil { lastFocused = nil; keyboardNavigating = false } }
        .onChange(of: controlActiveState) { if controlActiveState != .key { focused = nil; lastFocused = nil; keyboardNavigating = false } }
        .onChange(of: store.dockKeyboardFocusGeneration) {
            guard isPanel else { return }
            keyboardNavigating = true
            focusFirstItem()
        }
        .onChange(of: store.document.settings.position) { hovered = nil }
        .onHover { if $0 { refreshAvailability() } else { hovered = nil } }
        .onChange(of: store.isDockPointerInside) {
            if store.isDockPointerInside { refreshAvailability() }
            if isPanel && !store.isDockPointerInside { hovered = nil }
        }
        .overlayPreferenceValue(DockItemFrames.self) { frames in
            GeometryReader { geometry in
                Color.clear.onChange(of: menuRequest) {
                    guard let id = menuRequest else { return }
                    menuRequest = nil
                    if let frame = frames[id], let item = items.first(where: { $0.id == id }) {
                        presentMenu(for: item, itemFrame: frame, origin: geometry.frame(in: .global).origin)
                    }
                }
                if let labelID = hovered ?? (controlActiveState == .key && keyboardNavigating ? focused : nil), let frame = frames[labelID], let item = DockStore.hoverableItems(items).first(where: { $0.id == labelID }) {
                    let measured = (item.name as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium)]).width + 20
                    let width = DockLabelPlacement.width(measured: measured, available: vertical ? DockLabelPlacement.maxWidth : geometry.size.width - 16)
                    Text(item.name).font(.system(size: 12, weight: .medium))
                        .lineLimit(1).padding(.horizontal, 10).padding(.vertical, 6)
                        .frame(width: width).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                        .position(DockLabelPlacement.center(position: store.document.settings.position, itemFrame: frame,
                                                            bounds: geometry.size, width: width))
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }.allowsHitTesting(false)
        }
        .modifier(DockColorSchemeOverride(mode: store.appearance.colorMode, isPanel: isPanel))
    }

    @ViewBuilder
    private func barElement(_ item: DockItem, index: Int, hoveredIndex: Int?, runningIdentities: Set<String>) -> some View {
        Group {
            if item.kind == .spacer {
                Rectangle().fill(.primary.opacity(0.45))
                    .frame(width: vertical ? 50 : 1, height: vertical ? 1 : 40).padding(5)
            } else if item.kind == .clock {
                ClockTile(vertical: vertical).padding(vertical ? .vertical : .horizontal, 5)
                    .onHover { if $0 { hovered = nil } }
            } else if item.kind == .focusTimer {
                FocusTimerTile(itemID: item.id, vertical: vertical).padding(vertical ? .vertical : .horizontal, 5)
                    .onHover { if $0 { hovered = nil } }
            } else {
                dockItem(item, index: index, hoveredIndex: hoveredIndex, runningIdentities: runningIdentities)
            }
        }
        .background(GeometryReader { proxy in
            Color.clear.preference(key: DockItemFrames.self, value: [item.id: proxy.frame(in: .named(Self.space))])
        })
    }

    private static let space = "dockBar"

    @ViewBuilder
    private func dropIndicator(items: [DockItem]) -> some View {
        if let index = dropIndex {
            let frames = items.compactMap { itemRects[$0.id] }
            let mark = RoundedRectangle(cornerRadius: 1.5).fill(StudioColor.accent)
            GeometryReader { geometry in
                if let neighbor = frames.isEmpty ? nil : frames[min(index, frames.count - 1)] {
                    let edge = index < frames.count ? (vertical ? neighbor.minY : neighbor.minX) : (vertical ? neighbor.maxY : neighbor.maxX)
                    mark.frame(width: vertical ? neighbor.width : 3, height: vertical ? 3 : neighbor.height)
                        .position(x: vertical ? neighbor.midX : edge, y: vertical ? edge : neighbor.midY)
                } else {
                    mark.frame(width: vertical ? store.effectiveIconSize : 3, height: vertical ? 3 : store.effectiveIconSize)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
            .allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    private func dockItem(_ item: DockItem, index: Int, hoveredIndex: Int?, runningIdentities: Set<String>) -> some View {
        let magnificationEnabled = temporaryMagnificationEnabled ?? store.appearance.magnification
        let maximum = magnificationEnabled ? store.appearance.magnificationScale : 1
        let scale = DockAppearance.scale(index: index, hovered: hoveredIndex, maximum: maximum)
        let running = store.appearance.runningIndicators && item.applicationIdentity.map(runningIdentities.contains) == true
        let bouncing = store.document.settings.launchBounce && store.launchingItemIDs.contains(item.id)
            && !store.appearance.reduceMotion && !systemReduceMotion
        return VStack(spacing: 5) {
            Button {
                store.clickItem(item, modifiers: ItemClickPolicy.clickModifiers(event: NSApp.currentEvent?.modifierFlags,
                                                                                 current: NSEvent.modifierFlags))
            } label: {
                let icon = ItemIcon(item: item, size: store.effectiveIconSize * scale, style: store.appearance.iconStyle,
                                    availability: store.itemAvailability.status(of: item),
                                    glassNeedsContrast: store.appearance.background == .transparent,
                                    glassInteractive: !store.appearance.reduceMotion && !systemReduceMotion)
                    .shadow(color: .black.opacity(store.appearance.iconStyle == .glass ? 0 : 0.18), radius: 3, y: 2)
                if bouncing {
                    icon.modifier(LaunchBounce(position: store.document.settings.position,
                                               height: min(store.effectiveIconSize * 0.5, 28)))
                } else {
                    icon
                }
            }
            .buttonStyle(.plain)
            .focusable(false)
            .task(id: item.target) { await store.itemAvailability.refresh([item]) }
            .accessibilityLabel(running ? "\(item.name)、起動中" : item.name)
            .focusable()
            .focused($focused, equals: item.id)
            .onKeyPress(phases: [.down, .repeat]) { press in
                guard let key = DockKeyboardNavigation.Key(press) else { return .ignored }
                return handleKey(key, items: store.displayedItems) ? .handled : .ignored
            }
            .onKeyPress(.tab) { keyboardNavigating = true; return .ignored }
            .onKeyPress(.return) { store.openItem(item); return .handled }
            .onKeyPress(.space) { store.openItem(item); return .handled }
            .accessibilityActions {
                ForEach(actions(for: item).filter(\.isAccessibilityAction)) { action in
                    Button(action.title, action: action.perform)
                }
            }
            .contextMenu {
                ForEach(actions(for: item)) { action in
                    Button(action.title, role: action.isDestructive ? .destructive : nil, action: action.perform)
                }
            }
            Circle().fill(.white).overlay(Circle().stroke(.black.opacity(0.75), lineWidth: 0.7))
                .frame(width: 4, height: 4).opacity(running ? 1 : 0)
                .accessibilityHidden(true)
        }
        .padding(vertical ? .vertical : .horizontal, 5)
        .contentShape(Rectangle())
        .modifier(DragOutToRemove(enabled: store.isPinned(item) && !store.storageIsReadOnly, vertical: vertical,
                                  bounds: DockDragOutRemoval.visibleBounds(barSize: barSize, vertical: vertical,
                                                                           thickness: DockMetrics.barThickness(for: store))) {
            store.removeFromActiveProfile(item)
        })
        .onHover { if $0 { hovered = item.id } }
    }
}

extension DockBar {
    @ViewBuilder
    fileprivate func trashSection(index: Int, hoveredIndex: Int?) -> some View {
        let item = DockStore.trashItem
        let maximum = store.appearance.magnification ? store.appearance.magnificationScale : 1
        let scale = DockAppearance.scale(index: index, hovered: hoveredIndex, maximum: maximum)
        let state = store.trashState
        let symbol = switch state {
        case .empty: "trash"
        case .hasItems: "trash.fill"
        case .unknown: "trash.slash"
        }
        Rectangle().fill(.primary.opacity(0.45))
            .frame(width: vertical ? 50 : 1, height: vertical ? 1 : 40).padding(5)
        VStack(spacing: 5) {
            Button { store.openTrash() } label: {
                ItemIcon(item: item, size: store.effectiveIconSize * scale, style: store.appearance.iconStyle,
                         glassNeedsContrast: store.appearance.background == .transparent,
                         glassInteractive: !store.appearance.reduceMotion && !systemReduceMotion, symbol: symbol)
                    .shadow(color: .black.opacity(store.appearance.iconStyle == .glass ? 0 : 0.18), radius: 3, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.name)
            .accessibilityValue(state == .empty ? "空" : state == .hasItems ? "項目あり" : "状態を確認できません")
            .contextMenu { Button("開く") { store.openTrash() } }
            Circle().fill(.clear).frame(width: 4, height: 4).accessibilityHidden(true)
        }
        .padding(vertical ? .vertical : .horizontal, 5)
        .contentShape(Rectangle())
        .background(GeometryReader { proxy in
            Color.clear.preference(key: DockItemFrames.self, value: [item.id: proxy.frame(in: .named(Self.space))])
        })
        .onHover { if $0 { hovered = item.id } }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard !providers.isEmpty else { return false }
            Task { @MainActor in
                var urls: [URL] = []
                for provider in providers {
                    let url: URL? = await withCheckedContinuation { continuation in
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
                    }
                    if let url, url.isFileURL { urls.append(url) }
                }
                guard !urls.isEmpty else { return }
                store.moveDroppedItemsToTrash(urls)
            }
            return true
        }
    }
}

private struct DockItemAction: Identifiable {
    let kind: DockItemMenu.Kind
    let perform: () -> Void
    var id: DockItemMenu.Kind { kind }
    var title: String { kind.title }
    var isDestructive: Bool { kind == .remove || kind == .forceQuit }
    var isAccessibilityAction: Bool { kind.isAccessibilityAction }
}

extension DockBar {
    fileprivate static func entries(of items: [DockItem]) -> [DockKeyboardNavigation.Entry] {
        items.map { .init(name: $0.name, isFocusable: ![.spacer, .clock, .focusTimer].contains($0.kind)) }
    }

    fileprivate func actions(for item: DockItem) -> [DockItemAction] {
        let kinds = DockItemMenu.kinds(hasFileURL: item.targetURL?.isFileURL == true,
                                       visibility: store.applicationVisibility(item), canHideOthers: store.canHideOthers(item),
                                       canQuit: store.canQuitApplication(item), isPinned: store.isPinned(item))
        return kinds.map { kind in
            DockItemAction(kind: kind) {
                switch kind {
                case .open: store.openItem(item)
                case .reveal: if let url = item.targetURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                case .hide, .show: store.toggleApplicationVisibility(item)
                case .hideOthers: store.hideOthers(of: item)
                case .quit: store.quitApplication(item)
                case .forceQuit: store.forceQuitApplication(item)
                case .remove: store.removeFromActiveProfile(item)
                case .keep: store.keepInActiveProfile(item)
                }
            }
        }
    }

    fileprivate func focusFirstItem() {
        focusTask?.cancel()
        focusTask = Task { @MainActor in
            var assigned: UUID?
            var count = 0
            for _ in 0..<20 where !Task.isCancelled && count < 3 {
                try? await Task.sleep(for: .milliseconds(150))
                guard store.isDockPanelKey, focused == nil || focused == assigned,
                      case .focus(let index) = DockKeyboardNavigation.outcome(.first, entries: Self.entries(of: store.displayedItems), current: nil)
                else { continue }
                if assigned != nil {
                    focused = nil
                    try? await Task.sleep(for: .milliseconds(20))
                }
                assigned = store.displayedItems[index].id
                focused = assigned
                count += 1
            }
        }
    }

    fileprivate func focus(_ index: Int?, in items: [DockItem]) {
        focus(index.map(DockKeyboardNavigation.Outcome.focus) ?? .leave, in: items)
    }

    fileprivate func focus(_ outcome: DockKeyboardNavigation.Outcome, in items: [DockItem]) {
        switch outcome {
        case .focus(let index): focused = items[index].id
        case .leave:
            focused = nil
            if isPanel { store.dockKeyboardExitRequested = true }
        case .ignore: break
        }
    }

    fileprivate func handleKey(_ key: DockKeyboardNavigation.Key, items: [DockItem]) -> Bool {
        keyboardNavigating = true
        let current = focused.flatMap { id in items.firstIndex { $0.id == id } }
        if case .reorder(let arrow) = key {
            guard let offset = DockKeyboardNavigation.reorderOffset(for: arrow, position: store.document.settings.position),
                  let current, store.isPinned(items[current]),
                  let newIndex = store.moveActiveItem(items[current].id, by: offset) else { return false }
            let name = items[current].name
            NSAccessibility.post(element: NSApp.keyWindow ?? NSApp, notification: .announcementRequested,
                                 userInfo: [.announcement: "\(name)、\(newIndex + 1)番目"])
            return true
        }
        let entries = Self.entries(of: items)
        let command: DockKeyboardNavigation.Command? = switch key {
        case .home: .first
        case .end: .last
        case .arrow(let arrow): DockKeyboardNavigation.command(for: arrow, position: store.document.settings.position)
        case .reorder: nil
        case .character: nil
        }
        if let command {
            if command == .openMenu {
                if let current, !actions(for: items[current]).isEmpty { menuRequest = items[current].id }
            } else {
                focus(DockKeyboardNavigation.outcome(command, entries: entries, current: current), in: items)
            }
        } else if case .character(let characters) = key {
            let prefix = typeAhead.append(characters, at: .now)
            if let index = DockKeyboardNavigation.typeAheadIndex(prefix: prefix, entries: entries, current: current) {
                focused = items[index].id
            }
        }
        return true
    }

    fileprivate func presentMenu(for item: DockItem, itemFrame: CGRect, origin: CGPoint) {
        guard let window = NSApp.keyWindow else { return }
        let menu = NSMenu()
        for action in actions(for: item) {
            let entry = NSMenuItem(title: action.title, action: #selector(DockMenuHandler.run(_:)), keyEquivalent: "")
            entry.target = DockMenuHandler.shared
            entry.representedObject = action.perform
            menu.addItem(entry)
        }
        let left = window.frame.minX + origin.x + itemFrame.minX
        let top = window.frame.maxY - (origin.y + itemFrame.minY)
        let point: NSPoint = switch store.document.settings.position {
        case .bottom: NSPoint(x: left, y: top + menu.size.height)
        case .left: NSPoint(x: left + itemFrame.width, y: top)
        case .right: NSPoint(x: left - menu.size.width, y: top)
        }
        Task { @MainActor in menu.popUp(positioning: nil, at: point, in: nil) }
    }
}

@MainActor
private final class DockMenuHandler: NSObject {
    static let shared = DockMenuHandler()
    @objc func run(_ sender: NSMenuItem) { (sender.representedObject as? () -> Void)?() }
}

enum DockDropInsertion {
    static func index(at point: CGPoint, frames: [CGRect], vertical: Bool) -> Int {
        frames.firstIndex { vertical ? point.y < $0.midY : point.x < $0.midX } ?? frames.count
    }
}

private struct DockDropDelegate: DropDelegate {
    let store: DockStore
    let vertical: Bool
    let frames: [CGRect]
    let isMeasured: Bool
    @Binding var index: Int?

    func validateDrop(info: DropInfo) -> Bool {
        !store.storageIsReadOnly && isMeasured && info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) { index = DockDropInsertion.index(at: info.location, frames: frames, vertical: vertical) }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if index != nil { index = DockDropInsertion.index(at: info.location, frames: frames, vertical: vertical) }
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) { index = nil }

    func performDrop(info: DropInfo) -> Bool {
        let position = DockDropInsertion.index(at: info.location, frames: frames, vertical: vertical)
        let providers = info.itemProviders(for: [.fileURL])
        index = nil
        guard !providers.isEmpty else { return false }
        Task { @MainActor in
            var urls: [URL] = []
            for provider in providers {
                let url: URL? = await withCheckedContinuation { continuation in
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
                }
                if let url { urls.append(url) }
            }
            store.addDroppedItems(urls, at: position)
            index = nil
        }
        return true
    }
}

enum DockLabelPlacement {
    static let maxWidth: CGFloat = 240
    static let gap: CGFloat = 8

    static func width(measured: CGFloat, available: CGFloat) -> CGFloat {
        min(maxWidth, max(40, min(measured, available)))
    }

    static func center(position: DockPosition, itemFrame: CGRect, bounds: CGSize, width: CGFloat) -> CGPoint {
        switch position {
        case .bottom:
            return CGPoint(x: max(width / 2 + gap, min(bounds.width - width / 2 - gap, itemFrame.midX)),
                           y: max(16, itemFrame.minY - 18))
        case .left, .right:
            let y = max(16, min(bounds.height - 16, itemFrame.midY))
            return CGPoint(x: position == .left ? bounds.width + gap + width / 2 : -gap - width / 2, y: y)
        }
    }
}

private struct LaunchBounce: ViewModifier {
    let position: DockPosition
    let height: CGFloat

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, repeating: true) { view, lift in
            switch position {
            case .bottom: view.offset(y: -lift * height)
            case .left: view.offset(x: lift * height)
            case .right: view.offset(x: -lift * height)
            }
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1, duration: 0.28)
                CubicKeyframe(0, duration: 0.28)
                CubicKeyframe(0.4, duration: 0.18)
                CubicKeyframe(0, duration: 0.18)
                LinearKeyframe(0, duration: 0.2)
            }
        }
    }
}

private struct DockItemFrames: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct DockColorSchemeOverride: ViewModifier {
    let mode: DockAppearance.ColorMode
    let isPanel: Bool
    @Environment(\.colorScheme) private var environmentScheme
    @State private var appScheme = Self.scheme(of: NSApp.effectiveAppearance)

    private static func scheme(of appearance: NSAppearance) -> ColorScheme {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, isPanel ? environmentScheme : mode.colorScheme ?? appScheme)
            .onReceive(NSApp.publisher(for: \.effectiveAppearance)) { appScheme = Self.scheme(of: $0) }
    }
}

struct ItemIcon: View {
    let item: DockItem
    var size: Double = 40
    var style: DockAppearance.IconStyle = .original
    var availability: ItemAvailability = .available
    var glassNeedsContrast = false
    var glassInteractive = true
    var symbol: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if availability.isUnavailable {
                Image(systemName: availability == .volumeNotMounted ? "externaldrive.badge.xmark" : "questionmark.square.dashed")
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(Color.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.23))
                    .opacity(0.75)
            } else if let url = item.targetURL, url.isFileURL {
                Image(nsImage: DockIconRenderer.image(url: url, style: style, scheme: colorScheme))
                    .resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: symbol ?? item.kind.symbol)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(style == .original ? StudioColor.accent : .primary)
                    .opacity(style == .glass ? 0.72 : 1)
                    .frame(width: size, height: size)
                    .background(style == .original ? StudioColor.elevated : Color.primary.opacity(style == .glass ? 0 : 0.2),
                                in: RoundedRectangle(cornerRadius: size * 0.23))
            }
        }
        .frame(width: size, height: size)
        .modifier(DockIconGlassEffect(enabled: style == .glass, size: size,
                                      enhancedContrast: glassNeedsContrast, interactive: glassInteractive))
    }
}

private struct ClockTile: View {
    @Environment(DockStore.self) private var store
    @State private var popoverToken = UUID()
    let vertical: Bool
    @State private var expanded = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Button { expanded.toggle() } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.date, format: .dateTime.hour().minute()).font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text(context.date, format: .dateTime.month().day().weekday()).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(width: vertical ? 140 : 125, height: 54)
                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("時計")
            .accessibilityValue(context.date.formatted(date: .omitted, time: .shortened))
            .onChange(of: expanded) {
                if expanded { store.activePopoverTokens.insert(popoverToken) }
                else { store.activePopoverTokens.remove(popoverToken) }
            }
            .onDisappear { store.activePopoverTokens.remove(popoverToken) }
            .popover(isPresented: $expanded) {
                VStack(spacing: 12) {
                    Text(context.date, style: .time).font(.largeTitle.monospacedDigit())
                    Text(context.date, style: .date).foregroundStyle(.secondary)
                }.padding(25)
            }
        }
    }
}

private struct FocusTimerTile: View {
    @Environment(DockStore.self) private var store
    let itemID: UUID
    let vertical: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let session = store.focusSessions[itemID] ?? FocusSession()
            let seconds = session.seconds(at: context.date)
            Button {
                var next = session
                next.toggle()
                store.focusSessions[itemID] = next
            } label: {
                VStack(spacing: 3) {
                    Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                        .font(.system(size: 21, weight: .semibold, design: .rounded)).monospacedDigit()
                    Label(seconds == 0 ? "完了・もう一度" : session.deadline == nil ? "集中を開始" : "一時停止",
                          systemImage: session.deadline == nil ? "play.fill" : "pause.fill")
                        .font(.caption2).foregroundStyle(StudioColor.accent)
                }
                .frame(width: vertical ? 140 : 110, height: 54)
                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("集中タイマー \(seconds / 60) 分 \(seconds % 60) 秒")
            .contextMenu {
                Button("25 分に戻す") { store.focusSessions[itemID] = FocusSession() }
            }
        }
    }
}

@MainActor
enum DockMetrics {
    static func length(for store: DockStore, magnificationEnabled: Bool? = nil) -> CGFloat {
        let vertical = store.document.settings.position != .bottom
        let itemsTotal = store.displayedItems.reduce(24.0) { sum, item in
            sum + 10 + (item.kind == .spacer ? 11 :
                [.clock, .focusTimer].contains(item.kind) ? (vertical ? 54 : item.kind == .clock ? 125 : 110) : store.effectiveIconSize)
        }
        let minimizedWindows = Double(store.minimizedWindowController.windows.count) * (10 + store.effectiveIconSize)
        let total = itemsTotal + minimizedWindows + (10 + 11) + (10 + store.effectiveIconSize)
        let enabled = magnificationEnabled ?? store.appearance.magnification
        let reserve = enabled ? store.effectiveIconSize * (store.appearance.magnificationScale - 1) * 3 : 0
        return CGFloat(max(220, total + reserve))
    }
    static func barThickness(for store: DockStore, magnificationEnabled: Bool? = nil) -> CGFloat {
        let enabled = magnificationEnabled ?? store.appearance.magnification
        return CGFloat(store.document.settings.position == .bottom ? max(store.effectiveIconSize, 54) + 30 :
                    max(174, store.effectiveIconSize * (enabled ? store.appearance.magnificationScale : 1) + 32))
    }
    static let sideLabelGutter = DockLabelPlacement.maxWidth + DockLabelPlacement.gap
    static func thickness(for store: DockStore, magnificationEnabled: Bool? = nil) -> CGFloat {
        let enabled = magnificationEnabled ?? store.appearance.magnification
        let maximum = enabled ? store.appearance.magnificationScale : 1
        return store.document.settings.position == .bottom ? CGFloat(max(store.effectiveIconSize * maximum, 54) + 65) :
            barThickness(for: store, magnificationEnabled: enabled)
    }
}

struct DesktopBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(red: 0.12, green: 0.2, blue: 0.32), Color(red: 0.2, green: 0.15, blue: 0.29)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(StudioColor.accent.opacity(0.19))
                    .frame(width: geometry.size.width * 0.66).blur(radius: 90)
                    .offset(x: geometry.size.width * 0.27, y: -geometry.size.height * 0.25)
                Circle().fill(Color.purple.opacity(0.17))
                    .frame(width: geometry.size.width * 0.5).blur(radius: 90)
                    .offset(x: -geometry.size.width * 0.3, y: geometry.size.height * 0.35)
            }
        }.ignoresSafeArea()
    }
}

#Preview("Custom Dock") {
    CustomDockPreview().environment(DockStore.preview()).frame(width: 1080, height: 650).preferredColorScheme(.dark)
}
