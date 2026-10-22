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
        let position = store.document.settings.position
        let alignment: Alignment = switch store.document.settings.position {
        case .left: .leading
        case .bottom: .bottom
        case .right: .trailing
        }
        let noticeExtent = DockPreviewLayout.noticeExtent(
            hasNotice: DockPanelSizing.hasAccessibilityNotice(
                permissionGranted: store.notificationBadgeAccessibilityGranted,
                items: store.displayedItems
            )
        )
        let fittedIconSize = DockMetrics.effectiveIconSize(
            for: store, availableLength: max(0, size.height - 188 - noticeExtent), forceFit: true)
        let previewSize = DockPreviewLayout.frameSize(
            containerSize: size,
            position: position,
            length: DockMetrics.length(for: store, iconSize: vertical ? fittedIconSize : nil),
            thickness: DockMetrics.thickness(for: store),
            noticeExtent: noticeExtent
        )
        return DockBar(vertical: vertical,
                       availableLength: position == .bottom ? max(0, size.width - 50) : max(0, size.height - 188 - noticeExtent),
                       fitsAnyBackground: vertical)
            .environment(store)
            .frame(width: previewSize.width, height: previewSize.height)
            .clipShape(Rectangle())
            .padding(24)
            .padding(.bottom, position == .bottom ? 90 : 0)
            .padding(.vertical, vertical ? 70 : 0)
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
    @State private var folderContentsItem: DockItem?
    @State private var folderDisplayMode: FolderDisplayMode = .list
    @State private var keyboardNavigating = false
    @State private var focusTask: Task<Void, Never>?
    @State private var typeAhead = DockTypeAheadBuffer()
    @State private var confirmingTrashEmpty = false
    @State private var showingSpacesAssignmentGuide = false
    @State private var barSize: CGSize = .zero
    @State private var itemRects: [UUID: CGRect] = [:]
    @State private var dropIndex: Int?
    @State private var springLoadingTask: Task<Void, Never>?
    @State private var springLoadingTargetID: UUID?
    @State private var reorderIndex: Int?
    @State private var reorderSourceID: UUID?
    let vertical: Bool
    var isPanel = false
    var temporaryMagnificationEnabled: Bool?
    var availableLength: CGFloat?
    var fitsAnyBackground = false
    private var displayIconSize: Double {
        DockMetrics.effectiveIconSize(for: store, availableLength: availableLength,
                                      magnificationEnabled: temporaryMagnificationEnabled,
                                      forceFit: fitsAnyBackground)
    }
    private func backdropLength(hoveredIndex: Int?) -> CGFloat {
        let enabled = temporaryMagnificationEnabled ?? store.appearance.magnification
        return DockMetrics.backdropLength(for: store, iconSize: displayIconSize, axisPadding: itemAxisPadding,
                                          hoveredIndex: hoveredIndex,
                                          magnificationScale: enabled ? store.appearance.magnificationScale : 1,
                                          windowLength: DockMetrics.length(for: store, magnificationEnabled: enabled,
                                                                           iconSize: displayIconSize))
    }
    private var itemAxisPadding: CGFloat {
        guard store.appearance.background == .appleDock || fitsAnyBackground, store.effectiveIconSize > 0 else { return 5 }
        return CGFloat(5 * min(1, displayIconSize / store.effectiveIconSize))
    }
    private func refreshAvailability() {
        Task { await store.itemAvailability.refreshAll(minInterval: 1) }
    }

    private var motion: Animation? {
        store.appearance.reduceMotion || systemReduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82)
    }

    var body: some View {
        let displayedLayout = store.displayedLayout
        let items = displayedLayout.items
        let hoverIndex = DockStore.hoverableItems(items).firstIndex { $0.id == hovered }
        let running = Set(store.runningItems.compactMap(\.applicationIdentity))
        let showAccessibilityNotice = DockPanelSizing.hasAccessibilityNotice(
            permissionGranted: store.notificationBadgeAccessibilityGranted,
            items: items
        )
        VStack(spacing: showAccessibilityNotice ? DockPanelSizing.accessibilityNoticeSpacing : 0) {
            if showAccessibilityNotice {
                accessibilityPermissionNotice
                    .frame(width: isPanel ? DockPanelSizing.accessibilityNoticeWidth : nil)
                    .frame(maxWidth: .infinity)
                    .frame(height: DockPanelSizing.accessibilityNoticeHeight)
            }
            ZStack(alignment: vertical ? .center : .bottom) {
                DockBackdrop(appearance: store.appearance)
                    .frame(maxWidth: vertical ? nil : backdropLength(hoveredIndex: hoverIndex),
                           maxHeight: vertical ? backdropLength(hoveredIndex: hoverIndex) : nil)
                    .frame(width: vertical ? DockMetrics.backdropThickness(for: store) : nil,
                           height: vertical ? nil : DockMetrics.backdropThickness(for: store))
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
                                if displayedLayout.dividerBefore.contains(index) {
                                    Rectangle().fill(.primary.opacity(0.45))
                                        .frame(width: DockDividerLine.size(iconSize: displayIconSize, vertical: vertical).width,
                                               height: DockDividerLine.size(iconSize: displayIconSize, vertical: vertical).height)
                                        .dockDividerInsets(vertical: vertical)
                                        .accessibilityHidden(true)
                                }
                                barElement(item, index: index, hoveredIndex: hoverIndex, runningIdentities: running,
                                           spacerDrawsLine: DockTrashDivider.spacerDrawsLine(index: index, itemCount: items.count))
                            }
                            MinimizedWindowsDockSection(vertical: vertical, iconSize: displayIconSize,
                                                        iconStyle: store.appearance.iconStyle,
                                                        controller: store.minimizedWindowController,
                                                        groupedByApplication: store.document.settings.minimizeWindowsIntoAppIcon,
                                                        enabled: isPanel && store.isDockVisible)
                            trashSection(index: items.count, hoveredIndex: hoverIndex)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(minWidth: vertical ? nil : DockMetrics.length(for: store),
                           minHeight: vertical ? DockMetrics.length(for: store, iconSize: displayIconSize) : DockMetrics.thickness(for: store),
                           alignment: vertical ? .center : .bottom)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
        .coordinateSpace(name: DockDragOutRemoval.space)
        .onGeometryChange(for: CGSize.self, of: \.size) { barSize = $0 }
        .coordinateSpace(name: Self.space)
        .onPreferenceChange(DockItemFrames.self) { itemRects = $0 }
        .overlay { dropIndicator(items: items) }
        .overlay { reorderIndicator(items: items) }
        .onDrop(of: [.fileURL], delegate: DockDropDelegate(
            store: store, items: items, vertical: vertical, frames: itemRects,
            isMeasured: items.allSatisfy { itemRects[$0.id] != nil }, index: $dropIndex,
            springLoadingTask: $springLoadingTask, springLoadingTargetID: $springLoadingTargetID,
            folderContentsItem: $folderContentsItem, folderDisplayMode: $folderDisplayMode))
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
        .alert("Spaces への割り当て", isPresented: $showingSpacesAssignmentGuide) {
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(DockItemMenu.spacesAssignmentGuideMessage)
        }
        .task {
            while !Task.isCancelled {
                await store.refreshNotificationBadges()
                try? await Task.sleep(for: .seconds(2))
            }
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

    private var accessibilityPermissionNotice: some View {
        Button {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            Label("通知バッジにはアクセシビリティの許可が必要です", systemImage: "lock.fill")
                .font(.caption).padding(8)
                .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help("システム設定の「プライバシーとセキュリティ」で Dock Studio を許可してください")
    }

    @ViewBuilder
    private func barElement(_ item: DockItem, index: Int, hoveredIndex: Int?, runningIdentities: Set<String>,
                            spacerDrawsLine: Bool) -> some View {
        Group {
            if item.kind == .spacer {
                Rectangle().fill(.primary.opacity(spacerDrawsLine ? 0.45 : 0))
                    .frame(width: DockDividerLine.size(iconSize: displayIconSize, vertical: vertical).width,
                           height: DockDividerLine.size(iconSize: displayIconSize, vertical: vertical).height)
                    .dockDividerInsets(vertical: vertical)
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
                    mark.frame(width: vertical ? displayIconSize : 3, height: vertical ? 3 : displayIconSize)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
            .allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func reorderIndicator(items: [DockItem]) -> some View {
        if let index = reorderIndex, let movingID = reorderSourceID {
            let remaining = items.filter { $0.id != movingID }
            let frames = remaining.compactMap { itemRects[$0.id] }
            let mark = RoundedRectangle(cornerRadius: 1.5).fill(StudioColor.accent)
            GeometryReader { geometry in
                if let neighbor = frames.isEmpty ? nil : frames[min(index, frames.count - 1)] {
                    let edge = index < frames.count ? (vertical ? neighbor.minY : neighbor.minX) : (vertical ? neighbor.maxY : neighbor.maxX)
                    mark.frame(width: vertical ? neighbor.width : 3, height: vertical ? 3 : neighbor.height)
                        .position(x: vertical ? neighbor.midX : edge, y: vertical ? edge : neighbor.midY)
                } else {
                    mark.frame(width: vertical ? displayIconSize : 3, height: vertical ? 3 : displayIconSize)
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
        let attentionRequested = store.document.settings.attentionBounce
            && item.applicationIdentity.map(store.attentionRequestingIdentities.contains) == true
        let reduceMotion = store.appearance.reduceMotion || systemReduceMotion
        return Button {
                clickDockItem(item, modifiers: ItemClickPolicy.clickModifiers(event: NSApp.currentEvent?.modifierFlags,
                                                                                current: NSEvent.modifierFlags))
            } label: {
                VStack(spacing: 5) {
                    let icon = ItemIcon(item: item, size: displayIconSize * scale, style: store.appearance.iconStyle,
                                        availability: store.itemAvailability.status(of: item),
                                        glassNeedsContrast: store.appearance.background == .transparent,
                                        glassInteractive: !store.appearance.reduceMotion && !systemReduceMotion)
                        .shadow(color: .black.opacity(store.appearance.iconStyle == .glass ? 0 : 0.18), radius: 3, y: 2)
                        .overlay(alignment: .topTrailing) {
                            if let badge = NotificationBadgeSnapshot.badge(for: item, in: store.notificationBadges) {
                                Text(badge)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(.red, in: Capsule())
                                    .offset(x: 5, y: -4)
                                    .accessibilityHidden(true)
                            }
                        }
                    if bouncing || (attentionRequested && !reduceMotion) {
                        icon.modifier(LaunchBounce(position: store.document.settings.position,
                                                   height: min(displayIconSize * 0.5, 28)))
                    } else if attentionRequested {
                        icon.overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.9), lineWidth: 2)
                                .padding(2)
                        }
                    } else {
                        icon
                    }
                    Circle().fill(.white).overlay(Circle().stroke(.black.opacity(0.75), lineWidth: 0.7))
                        .frame(width: 4, height: 4).opacity(running ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .padding(vertical ? .vertical : .horizontal, itemAxisPadding)
                .contentShape(DockItemHitShape())
            }
            .buttonStyle(.plain)
            .popover(isPresented: folderPopoverBinding(for: item), arrowEdge: folderPopoverEdge) {
                if let folder = folderContentsItem {
                    FolderContentsPopover(folder: folder, displayMode: $folderDisplayMode,
                                          onDisplayModeChange: { mode in
                        if store.setFolderDisplayMode(mode, forItem: folder.id) {
                            var updated = folder
                            updated.folderDisplayMode = mode
                            folderContentsItem = updated
                        }
                    }, dockPosition: store.document.settings.position,
                                          reduceMotion: store.appearance.reduceMotion || systemReduceMotion,
                                          openItem: { child in
                        folderContentsItem = nil
                        store.openItem(child)
                    }, openInFinder: { folder in
                        store.clickItem(folder, modifiers: .command)
                        folderContentsItem = nil
                    }, moveDroppedItemsIntoFolder: { urls, folderURL in
                        store.moveDroppedItemsIntoFolder(urls, at: folderURL)
                    }, updateDisplayStyle: { folder, style in
                        store.updateFolderContentsDisplayStyle(style, for: folder.id)
                    }, onSortOrderChange: { order in
                        store.setFolderSortOrder(order, for: folder.id)
                    })
                }
            }
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
            .onKeyPress(.return) { activateDockItem(item); return .handled }
            .onKeyPress(.space) { activateDockItem(item); return .handled }
            .accessibilityActions {
                ForEach(actions(for: item).filter(\.isAccessibilityAction)) { action in
                    Button(action.title, action: action.perform)
                        .disabled(!action.isEnabled)
                }
                if item.kind == .application, item.applicationIdentity?.hasPrefix("bundle:") == true {
                    ForEach(DockApplicationWindowMenuModel.entries(from: store.applicationWindowListing(for: item)), id: \.self) { entry in
                        switch entry {
                        case .window(let id, let title):
                            Button("ウィンドウを前面に表示: \(title)") { store.activateApplicationWindow(id, for: item) }
                        case .unavailable(let title):
                            Button(title) {}.disabled(true)
                        }
                    }
                }
            }
            .contextMenu {
                ForEach(actions(for: item)) { action in
                    if action.kind == .windowList {
                        Menu(action.title) {
                            ForEach(DockApplicationWindowMenuModel.entries(from: store.applicationWindowListing(for: item)), id: \.self) { entry in
                                switch entry {
                                case .window(let id, let title):
                                    Button(title) { store.activateApplicationWindow(id, for: item) }
                                case .unavailable(let title):
                                    Button(title) {}.disabled(true)
                                }
                            }
                        }
                    } else {
                        Button(action.title, role: action.isDestructive ? .destructive : nil, action: action.perform)
                            .disabled(!action.isEnabled)
                    }
                }
                if supportsApplicationDockMenu(item) {
                    Button("アプリ固有メニュー…") { showApplicationDockMenu(for: item) }
                }
            }
        .modifier(DragOutToRemove(enabled: store.isPinned(item) && !store.storageIsReadOnly &&
                                  !(store.document.settings.finderEntryEnabled && FinderDockEntry.isFinder(item)), vertical: vertical,
                                  bounds: DockDragOutRemoval.visibleBounds(barSize: barSize, vertical: vertical,
                                                                           thickness: DockMetrics.barThickness(for: store)),
                                  onRemove: {
            store.removeFromActiveProfile(item)
        }, isEjectable: {
            VolumeEjector().isEjectable(item)
        }, onEject: {
            store.ejectVolume(item)
        }, onDragMove: { point in
            guard let point else { reorderIndex = nil; return }
            reorderSourceID = item.id
            let layout = store.displayedLayout
            let remaining = layout.items.filter { $0.id != item.id }
            let frames = remaining.compactMap { itemRects[$0.id] }
            let insertion = DockItemReordering.insertionIndex(at: point, frames: frames, vertical: vertical)
            reorderIndex = DockItemReordering.clampedInsertionIndex(displayedItems: layout.items,
                                                                    dividerBefore: layout.dividerBefore,
                                                                    movingID: item.id,
                                                                    insertionIndex: insertion)
        }, onDragFinish: { point, cancelled in
            defer { reorderIndex = nil; reorderSourceID = nil }
            guard !cancelled, let point else { return }
            let layout = store.displayedLayout
            let remaining = layout.items.filter { $0.id != item.id }
            let frames = remaining.compactMap { itemRects[$0.id] }
            let insertion = DockItemReordering.insertionIndex(at: point, frames: frames, vertical: vertical)
            guard let index = DockItemReordering.clampedInsertionIndex(displayedItems: layout.items,
                                                                       dividerBefore: layout.dividerBefore,
                                                                       movingID: item.id,
                                                                       insertionIndex: insertion) else { return }
            store.reorderActiveItem(item.id, insertionIndex: index,
                                    displayedItems: layout.items, dividerBefore: layout.dividerBefore)
        }))
        .onHover { if $0 { hovered = item.id } }
    }

    private func folderPopoverBinding(for item: DockItem) -> Binding<Bool> {
        Binding(
            get: { folderContentsItem?.id == item.id },
            set: { isPresented in
                if !isPresented, folderContentsItem?.id == item.id { folderContentsItem = nil }
            }
        )
    }

    private var folderPopoverEdge: Edge {
        if vertical {
            return store.document.settings.position == .left ? .leading : .trailing
        }
        return .bottom
    }

    private func clickDockItem(_ item: DockItem, modifiers: NSEvent.ModifierFlags) {
        if item.kind == .folder,
           !ItemClickPolicy.isRevealClick(modifiers),
           !ItemClickPolicy.isHideOthersClick(modifiers) {
            folderContentsItem = item
            folderDisplayMode = item.folderDisplayMode ?? .list
        } else {
            store.clickItem(item, modifiers: modifiers)
        }
    }

    private func activateDockItem(_ item: DockItem) {
        if item.kind == .folder {
            folderContentsItem = item
            folderDisplayMode = item.folderDisplayMode ?? .list
        } else {
            store.openItem(item)
        }
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
        DockIconSizeResizeHandle(vertical: vertical, iconSize: displayIconSize)
            .dockDividerInsets(vertical: vertical)
            .modifier(DockSeparatorContextMenu(store: store))
        VStack(spacing: 5) {
            Button { store.openTrash() } label: {
                ItemIcon(item: item, size: displayIconSize * scale, style: store.appearance.iconStyle,
                         glassNeedsContrast: store.appearance.background == .transparent,
                         glassInteractive: !store.appearance.reduceMotion && !systemReduceMotion, symbol: symbol)
                    .shadow(color: .black.opacity(store.appearance.iconStyle == .glass ? 0 : 0.18), radius: 3, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.name)
            .accessibilityValue(state == .empty ? "空" : state == .hasItems ? "項目あり" : store.trashStateGuidance)
            .help(state == .unknown ? store.trashStateGuidance : "")
            .contextMenu {
                Button("開く") { store.openTrash() }
                if state == .unknown {
                    Button("状態の確認方法") { store.explainTrashState() }
                }
                if store.isEmptyingTrash {
                    Button("ゴミ箱を空にしています…") {}.disabled(true)
                } else {
                    Button("ゴミ箱を空にする…", role: .destructive) { confirmingTrashEmpty = true }
                }
            }
            .confirmationDialog("ゴミ箱を空にしますか？", isPresented: $confirmingTrashEmpty) {
                Button("ゴミ箱を空にする", role: .destructive) { store.emptyTrash() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("ゴミ箱内のすべての項目を完全に削除します。この操作は取り消せません。Finder がロックされた項目を確認する場合があります。")
            }
            Circle().fill(.clear).frame(width: 4, height: 4).accessibilityHidden(true)
        }
        .padding(vertical ? .vertical : .horizontal, itemAxisPadding)
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
                if DockDropRouting.decision(for: .trash) == .moveToTrash {
                    store.moveDroppedItemsToTrash(urls)
                }
            }
            return true
        }
    }
}

private struct DockItemAction: Identifiable {
    let kind: DockItemMenu.Kind
    let perform: () -> Void
    var isEnabled = true
    var titleOverride: String?
    var id: DockItemMenu.Kind { kind }
    var title: String { titleOverride ?? kind.title }
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
                                       canQuit: store.canQuitApplication(item), isPinned: store.isPinned(item),
                                       isFinder: FinderDockEntry.isFinder(item),
                                       finderEntryEnabled: store.document.settings.finderEntryEnabled,
                                       folderDisplayStyle: item.kind == .folder ? item.effectiveFolderDisplayStyle : nil,
                                       isApplication: item.kind == .application,
                                       hasWindowList: item.kind == .application && item.applicationIdentity?.hasPrefix("bundle:") == true,
                                       optionKeyDown: (NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags).contains(.option))
        let appExposeAction = item.kind == .application && item.targetURL?.isFileURL == true
            ? [DockItemMenu.Kind.showAllWindows]
            : []
        return (kinds + appExposeAction).map { kind in
            DockItemAction(kind: kind, perform: {
                switch kind {
                case .open: store.openItem(item)
                case .reveal: if let url = item.targetURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                case .showAllWindows: store.showAllWindows(for: item)
                case .windowList: break
                case .spacesAssignmentGuide: showingSpacesAssignmentGuide = true
                case .openLoginItemsSettings: store.loginItem.openSystemSettings()
                case .hide, .show: store.toggleApplicationVisibility(item)
                case .hideOthers: store.hideOthers(of: item)
                case .quit: store.quitApplication(item)
                case .forceQuit: store.forceQuitApplication(item)
                case .remove: store.removeFromActiveProfile(item)
                case .keep: store.keepInActiveProfile(item)
                case .finderNewWindow: FinderDockEntry.openNewWindow()
                case .finderShowAllWindows: FinderDockEntry.showFinder()
                case .setFolderIcon: store.setFolderDisplayStyle(.folder, for: item.id)
                case .setStackIcon: store.setFolderDisplayStyle(.stack, for: item.id)
                }
            }, isEnabled: kind == .showAllWindows ? store.canShowAllWindows(for: item) : true,
               titleOverride: kind == .showAllWindows ? store.showAllWindowsActionTitle(for: item) : nil)
        }
    }

    fileprivate func supportsApplicationDockMenu(_ item: DockItem) -> Bool {
        item.kind == .application && item.targetURL?.isFileURL == true
    }

    fileprivate func showApplicationDockMenu(for item: DockItem) {
        guard let applicationURL = item.targetURL,
              let items = store.applicationDockMenuAccess.menu(for: applicationURL), !items.isEmpty else {
            store.errorMessage = "\(item.name) のアプリ固有メニューを取得できませんでした。アクセシビリティ権限と標準 Dock への登録を確認してください。"
            return
        }
        let menu = NSMenu()
        appendApplicationDockMenuItems(items, to: menu, applicationURL: applicationURL, itemName: item.name)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    fileprivate func appendApplicationDockMenuItems(_ items: [ApplicationDockMenuItem], to menu: NSMenu,
                                                      applicationURL: URL, itemName: String) {
        for item in items {
            let entry = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
            if item.children.isEmpty {
                entry.action = #selector(DockMenuHandler.run(_:))
                entry.target = DockMenuHandler.shared
                entry.representedObject = { [store] in
                    guard store.applicationDockMenuAccess.perform(itemID: item.id, for: applicationURL) else {
                        store.errorMessage = "\(itemName) の「\(item.title)」を実行できませんでした。"
                        return
                    }
                    store.status = "\(itemName) の「\(item.title)」を実行しました"
                }
            } else {
                let submenu = NSMenu()
                appendApplicationDockMenuItems(item.children, to: submenu, applicationURL: applicationURL,
                                               itemName: itemName)
                entry.submenu = submenu
            }
            menu.addItem(entry)
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
                  !(store.document.settings.finderEntryEnabled && FinderDockEntry.isFinder(items[current])),
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
            if action.kind == .windowList {
                let windowMenu = NSMenuItem(title: action.title, action: nil, keyEquivalent: "")
                let submenu = NSMenu()
                let controller = DockApplicationWindowMenuController(
                    listing: { store.applicationWindowListing(for: item) },
                    activate: { windowID in store.activateApplicationWindow(windowID, for: item) })
                submenu.delegate = controller
                windowMenu.submenu = submenu
                windowMenu.representedObject = controller
                menu.addItem(windowMenu)
                continue
            }
            let entry = NSMenuItem(title: action.title, action: #selector(DockMenuHandler.run(_:)), keyEquivalent: "")
            entry.target = DockMenuHandler.shared
            entry.representedObject = action.perform
            menu.addItem(entry)
        }
        if supportsApplicationDockMenu(item) {
            let appMenu = NSMenuItem(title: "アプリ固有メニュー…", action: #selector(DockMenuHandler.run(_:)),
                                     keyEquivalent: "")
            appMenu.target = DockMenuHandler.shared
            appMenu.representedObject = { showApplicationDockMenu(for: item) }
            menu.addItem(appMenu)
        }
        let recentDocuments = store.recentDocuments(for: item)
        if !recentDocuments.isEmpty {
            let recentItem = NSMenuItem(title: "最近使った書類", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for document in recentDocuments {
                let entry = NSMenuItem(title: document.title, action: #selector(DockMenuHandler.run(_:)), keyEquivalent: "")
                entry.target = DockMenuHandler.shared
                entry.representedObject = { store.openRecentDocument(document.id, for: item) }
                submenu.addItem(entry)
            }
            recentItem.submenu = submenu
            menu.addItem(recentItem)
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

@MainActor
private final class DockApplicationWindowMenuController: NSObject, NSMenuDelegate {
    private let listing: () -> ApplicationWindowListing
    private let activate: (String) -> Void

    init(listing: @escaping () -> ApplicationWindowListing, activate: @escaping (String) -> Void) {
        self.listing = listing
        self.activate = activate
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for entry in DockApplicationWindowMenuModel.entries(from: listing()) {
            switch entry {
            case .window(let id, let title):
                let item = NSMenuItem(title: title, action: #selector(DockMenuHandler.run(_:)), keyEquivalent: "")
                item.target = DockMenuHandler.shared
                item.representedObject = { [activate] in activate(id) }
                menu.addItem(item)
            case .unavailable(let title):
                menu.addItem(disabledItem(title))
            }
        }
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

enum DockDropInsertion {
    static func index(at point: CGPoint, frames: [CGRect], vertical: Bool) -> Int {
        frames.firstIndex { vertical ? point.y < $0.midY : point.x < $0.midX } ?? frames.count
    }
}

private struct DockDropDelegate: DropDelegate {
    let store: DockStore
    let items: [DockItem]
    let vertical: Bool
    let frames: [UUID: CGRect]
    let isMeasured: Bool
    @Binding var index: Int?
    @Binding var springLoadingTask: Task<Void, Never>?
    @Binding var springLoadingTargetID: UUID?
    @Binding var folderContentsItem: DockItem?
    @Binding var folderDisplayMode: FolderDisplayMode

    private var orderedFrames: [CGRect] { items.compactMap { frames[$0.id] } }

    func validateDrop(info: DropInfo) -> Bool {
        guard isMeasured, info.hasItemsConforming(to: [.fileURL]) else { return false }
        return applicationTarget(at: info.location) != nil || folderTarget(at: info.location) != nil || !store.storageIsReadOnly
    }

    func dropEntered(info: DropInfo) {
        updateInsertionIndex(at: info.location)
        updateSpringLoading(at: info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateInsertionIndex(at: info.location)
        updateSpringLoading(at: info.location)
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        index = nil
        cancelSpringLoading()
    }

    func performDrop(info: DropInfo) -> Bool {
        let position = insertionIndex(at: info.location)
        let applicationTarget = applicationTarget(at: info.location)
        let folderTarget = folderTarget(at: info.location)
        let providers = info.itemProviders(for: [.fileURL])
        index = nil
        cancelSpringLoading()
        guard !providers.isEmpty else { return false }
        guard applicationTarget != nil || folderTarget != nil || !store.storageIsReadOnly else { return false }
        Task { @MainActor in
            var urls: [URL] = []
            for provider in providers {
                let url: URL? = await withCheckedContinuation { continuation in
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
                }
                if let url { urls.append(url) }
            }
            let target: DockDropTarget
            if let applicationTarget {
                target = .application(applicationTarget)
            } else if let folderTarget {
                target = .folder(folderTarget.targetURL)
            } else {
                target = .insertion(position)
            }
            let decision = DockDropRouting.decision(
                for: target,
                folderIsAvailable: folderTarget.map { Self.isAvailableFolder($0.targetURL) } ?? true
            )
            switch decision {
            case .openWithApplication(let item):
                store.openDroppedFiles(urls, with: item)
            case .moveIntoFolder(let url):
                store.moveDroppedItemsIntoFolder(urls, at: url)
            case .insert(let index):
                store.addDroppedItems(urls, at: index)
            case .moveToTrash:
                store.moveDroppedItemsToTrash(urls)
            case .refuse(let reason):
                store.errorMessage = reason
            }
            index = nil
        }
        return true
    }

    private func applicationTarget(at point: CGPoint) -> DockItem? {
        DockDropRouting.applicationTarget(at: point, items: items, frames: frames)
    }

    private func folderTarget(at point: CGPoint) -> DockItem? {
        items.first { $0.kind == .folder && frames[$0.id]?.contains(point) == true }
    }

    private static func isAvailableFolder(_ url: URL?) -> Bool {
        guard let url, url.isFileURL,
              let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) else { return false }
        return values.isDirectory == true
    }

    private func insertionIndex(at point: CGPoint) -> Int {
        DockDropInsertion.index(at: point, frames: orderedFrames, vertical: vertical)
    }

    private func updateInsertionIndex(at point: CGPoint) {
        index = applicationTarget(at: point) == nil && !store.storageIsReadOnly ? insertionIndex(at: point) : nil
    }

    private func updateSpringLoading(at point: CGPoint) {
        guard DockSpringLoadingPreferences.isEnabled, let folder = folderTarget(at: point) else {
            cancelSpringLoading()
            return
        }
        guard springLoadingTargetID != folder.id else { return }
        cancelSpringLoading()
        springLoadingTargetID = folder.id
        springLoadingTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(DockSpringLoading.hoverDelay))
            } catch {
                return
            }
            guard springLoadingTargetID == folder.id else { return }
            guard DockSpringLoading.action(for: folder.kind, elapsed: DockSpringLoading.hoverDelay,
                                           enabled: DockSpringLoadingPreferences.isEnabled) == .openFolder else {
                cancelSpringLoading()
                return
            }
            folderContentsItem = folder
            folderDisplayMode = folder.folderDisplayMode ?? .list
            springLoadingTask = nil
            springLoadingTargetID = nil
        }
    }

    private func cancelSpringLoading() {
        springLoadingTask?.cancel()
        springLoadingTask = nil
        springLoadingTargetID = nil
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
    var appliesGlassEffect = true
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
            } else if item.kind == .folder, item.effectiveFolderDisplayStyle == .stack {
                FolderStackIcon(folder: item, size: size, style: style)
            } else if let url = item.targetURL, url.isFileURL {
                Image(nsImage: DockIconRenderer.image(url: url, style: style, pointSize: size, scheme: colorScheme))
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
        .modifier(DockIconGlassEffect(enabled: appliesGlassEffect && style == .glass, size: size,
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
    static func effectiveIconSize(for store: DockStore, availableLength: CGFloat?,
                                  magnificationEnabled: Bool? = nil, forceFit: Bool = false) -> Double {
        let maximumSize = store.effectiveIconSize
        guard forceFit || store.appearance.background == .appleDock, let availableLength else { return maximumSize }

        let vertical = store.document.settings.position != .bottom
        if vertical {
            return DockVerticalFit.iconSize(verticalFitContent(for: store, magnificationEnabled: magnificationEnabled),
                                            maximumSize: maximumSize,
                                            minimumSize: DockSettings.iconSizeRange.lowerBound,
                                            availableLength: Double(availableLength))
        }
        let fixedItemsLength = store.displayedItems.reduce(24.0) { sum, item in
            sum + ([.spacer, .clock, .focusTimer].contains(item.kind) ? 10 : 0)
                + (item.kind == .spacer ? 11 :
                    [.clock, .focusTimer].contains(item.kind) ? (vertical ? 54 : item.kind == .clock ? 125 : 110) : 0)
        }
        let scalableItems = store.displayedItems.filter {
            ![.spacer, .clock, .focusTimer].contains($0.kind)
        }.count
        let minimizedWindowCount = store.minimizedWindowController.state.reservedSlots
        let fixedLength = fixedItemsLength + 21
        let enabled = magnificationEnabled ?? store.appearance.magnification
        let magnificationReserve = enabled
            ? max(0, store.appearance.magnificationScale - 1) * 3
            : 0
        let paddedItemCount = Double(scalableItems + 1)
        let scalableLength = paddedItemCount * (1 + 10 / maximumSize)
            + Double(minimizedWindowCount) + magnificationReserve

        return DockIconAutoShrink.size(maximumSize: maximumSize,
                                       minimumSize: DockSettings.iconSizeRange.lowerBound,
                                       availableLength: Double(availableLength),
                                       fixedLength: fixedLength,
                                       scalableLength: scalableLength)
    }

    static func minimizedSectionLength(slots: Int, iconSize: Double) -> Double {
        Double(slots) * (10 + iconSize)
    }

    static let verticalItemPadding = DockVerticalFit.itemExtraPadding + 10
    static let verticalSeparatorLength = DockVerticalFit.separatorLength

    static func verticalFitContent(for store: DockStore, magnificationEnabled: Bool? = nil) -> DockVerticalFit.Content {
        let enabled = magnificationEnabled ?? store.appearance.magnification
        let isIcon = { (item: DockItem) in ![.spacer, .clock, .focusTimer].contains(item.kind) }
        let fixed = store.displayedItems.filter { !isIcon($0) }.reduce(24.0) { sum, item in
            sum + 10 + (item.kind == .spacer ? 11 : 54)
        }
        return DockVerticalFit.Content(
            fixedLength: fixed,
            iconItemCount: store.displayedItems.filter(isIcon).count,
            minimizedSlots: store.minimizedWindowController.state.reservedSlots,
            magnificationReserve: enabled ? max(0, store.appearance.magnificationScale - 1) * 3 : 0)
    }

    static func length(for store: DockStore, magnificationEnabled: Bool? = nil, iconSize: Double? = nil) -> CGFloat {
        let vertical = store.document.settings.position != .bottom
        let iconSize = iconSize ?? store.effectiveIconSize
        let itemPadding = vertical
            ? DockVerticalFit.itemExtraPadding + 10 * iconSize / max(1, store.effectiveIconSize) : 10.0
        let itemsTotal = store.displayedItems.reduce(24.0) { sum, item in
            sum + ([.spacer, .clock, .focusTimer].contains(item.kind) ? 10 : itemPadding) + (item.kind == .spacer ? 11 :
                [.clock, .focusTimer].contains(item.kind) ? (vertical ? 54 : item.kind == .clock ? 125 : 110) : iconSize)
        }
        let minimizedWindows = minimizedSectionLength(slots: store.minimizedWindowController.state.reservedSlots,
                                                      iconSize: iconSize)
        let total = itemsTotal + minimizedWindows + (vertical ? verticalSeparatorLength : 10 + 11)
            + (itemPadding + iconSize)
        let enabled = magnificationEnabled ?? store.appearance.magnification
        let reserve = enabled ? iconSize * (store.appearance.magnificationScale - 1) * 3 : 0
        return CGFloat(max(220, total + reserve))
    }
    static func barThickness(for store: DockStore, magnificationEnabled: Bool? = nil) -> CGFloat {
        let enabled = magnificationEnabled ?? store.appearance.magnification
        return CGFloat(store.document.settings.position == .bottom ? max(store.effectiveIconSize, 54) + 30 :
                    max(174, store.effectiveIconSize * (enabled ? store.appearance.magnificationScale : 1) + 32))
    }
    static func backdropThickness(for store: DockStore) -> CGFloat {
        let hasTile = store.displayedItems.contains { [.clock, .focusTimer].contains($0.kind) }
        return store.document.settings.position == .bottom
            ? DockBackdropFit.bottomThickness(iconSize: store.effectiveIconSize, hasTile: hasTile)
            : DockBackdropFit.sideThickness(iconSize: store.effectiveIconSize, hasTile: hasTile)
    }
    static func backdropLength(for store: DockStore, iconSize: Double, axisPadding: CGFloat,
                               hoveredIndex: Int? = nil, magnificationScale: Double = 1,
                               windowLength: CGFloat = .infinity) -> CGFloat {
        let vertical = store.document.settings.position != .bottom
        let layout = store.displayedLayout
        var fixed = CGFloat(layout.dividerBefore.count) * 11
        var iconItems = 0
        var scales: [Double] = []
        for (index, item) in layout.items.enumerated() {
            switch item.kind {
            case .spacer: fixed += 11
            case .clock: fixed += vertical ? 64 : 135
            case .focusTimer: fixed += vertical ? 64 : 120
            default:
                iconItems += 1
                scales.append(DockAppearance.scale(index: index, hovered: hoveredIndex, maximum: magnificationScale))
            }
        }
        scales.append(DockAppearance.scale(index: layout.items.count, hovered: hoveredIndex, maximum: magnificationScale))
        let base = DockBackdropFit.length(
            .init(iconItems: iconItems, fixedExtent: fixed,
                  minimizedSlots: store.minimizedWindowController.state.reservedSlots),
            iconSize: iconSize, axisPadding: axisPadding, vertical: vertical)
        return DockBackdropFit.magnifiedLength(base: base, iconSize: iconSize, scales: scales, windowLength: windowLength)
    }
    static let sideLabelGutter = DockLabelPlacement.maxWidth + DockLabelPlacement.gap
    static func thickness(for store: DockStore, magnificationEnabled: Bool? = nil) -> CGFloat {
        let enabled = magnificationEnabled ?? store.appearance.magnification
        let maximum = enabled ? store.appearance.magnificationScale : 1
        return store.document.settings.position == .bottom ? CGFloat(max(store.effectiveIconSize * maximum, 54) + 65) :
            barThickness(for: store, magnificationEnabled: enabled)
    }
}

enum DockPreviewLayout {
    static func noticeExtent(hasNotice: Bool) -> CGFloat {
        hasNotice ? DockPanelSizing.accessibilityNoticeHeight + DockPanelSizing.accessibilityNoticeSpacing : 0
    }

    static func frameSize(containerSize: CGSize, position: DockPosition, length: CGFloat, thickness: CGFloat,
                          noticeExtent: CGFloat = 0) -> CGSize {
        let availableWidth = max(0, containerSize.width - 50)
        let availableHeight = max(0, containerSize.height - 188)
        if position == .bottom {
            return CGSize(width: min(availableWidth, max(0, length)),
                          height: min(availableHeight, max(0, thickness) + max(0, noticeExtent)))
        }
        return CGSize(width: min(190, availableWidth),
                      height: min(availableHeight, max(0, length) + max(0, noticeExtent)))
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
