import SwiftUI

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
    @State private var hovered: UUID?
    let vertical: Bool
    var isPanel = false
    private var motion: Animation? {
        store.appearance.reduceMotion || systemReduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82)
    }

    var body: some View {
        let items = store.displayedItems
        let hoverIndex = items.firstIndex { $0.id == hovered }
        let running = Set(store.runningItems.compactMap(\.applicationIdentity))
        ZStack(alignment: vertical ? .center : .bottom) {
            DockBackdrop(appearance: store.appearance)
                .frame(width: vertical ? DockMetrics.barThickness(for: store) : nil,
                       height: vertical ? nil : DockMetrics.barThickness(for: store))
                .shadow(color: .black.opacity(store.appearance.background == .transparent || store.appearance.background == .appleDock ? 0 : 0.18), radius: 4, y: -2)
            ScrollView(vertical ? .vertical : .horizontal) {
                let layout = vertical ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(alignment: .bottom, spacing: 0))
                DockGlassContainer(enabled: store.appearance.iconStyle == .glass) {
                    layout {
                        if items.isEmpty {
                            Label("プロファイルに項目を追加", systemImage: "plus.circle")
                                .font(.callout).foregroundStyle(StudioColor.muted).padding(10)
                        }
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if item.kind == .spacer {
                                Rectangle().fill(.white.opacity(0.55)).shadow(color: .black.opacity(0.75), radius: 1)
                                    .frame(width: vertical ? 50 : 1, height: vertical ? 1 : 40).padding(5)
                            } else if item.kind == .clock {
                                ClockTile(vertical: vertical).padding(vertical ? .vertical : .horizontal, 5)
                                    .onHover { if $0 { hovered = nil } }
                            } else if item.kind == .focusTimer {
                                FocusTimerTile(itemID: item.id, vertical: vertical).padding(vertical ? .vertical : .horizontal, 5)
                                    .onHover { if $0 { hovered = nil } }
                            } else {
                                dockItem(item, index: index, hoveredIndex: hoverIndex, runningIdentities: running)
                            }
                        }
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
        .animation(motion, value: hovered)
        .onChange(of: items.map(\.id)) { hovered = nil }
        .onChange(of: store.document.settings.position) { hovered = nil }
        .onHover { if !$0 { hovered = nil } }
        .onChange(of: store.isDockPointerInside) { if isPanel && !store.isDockPointerInside { hovered = nil } }
        .overlayPreferenceValue(DockItemFrames.self) { frames in
            GeometryReader { geometry in
                if !vertical, let hovered, let anchor = frames[hovered], let item = items.first(where: { $0.id == hovered }) {
                    let frame = geometry[anchor]
                    let measured = (item.name as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium)]).width + 20
                    let width = min(240, max(40, min(measured, geometry.size.width - 16)))
                    Text(item.name).font(.system(size: 12, weight: .medium))
                        .lineLimit(1).padding(.horizontal, 10).padding(.vertical, 6)
                        .frame(width: width).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                        .position(x: max(width / 2 + 8, min(geometry.size.width - width / 2 - 8, frame.midX)),
                                  y: max(16, frame.minY - 18))
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }.allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
    }

    private func dockItem(_ item: DockItem, index: Int, hoveredIndex: Int?, runningIdentities: Set<String>) -> some View {
        let maximum = store.appearance.magnification ? store.appearance.magnificationScale : 1
        let scale = DockAppearance.scale(index: index, hovered: hoveredIndex, maximum: maximum)
        let running = store.appearance.runningIndicators && item.applicationIdentity.map(runningIdentities.contains) == true
        return VStack(spacing: 5) {
            Button { store.openItem(item) } label: {
                ItemIcon(item: item, size: store.effectiveIconSize * scale, style: store.appearance.iconStyle,
                         glassNeedsContrast: store.appearance.background == .transparent,
                         glassInteractive: !store.appearance.reduceMotion && !systemReduceMotion)
                    .shadow(color: .black.opacity(store.appearance.iconStyle == .glass ? 0 : 0.18), radius: 3, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(running ? "\(item.name)、起動中" : item.name)
            .focusable()
            .onKeyPress(.return) { store.openItem(item); return .handled }
            .onKeyPress(.space) { store.openItem(item); return .handled }
            .contextMenu {
                Button("開く") { store.openItem(item) }
                if let url = item.targetURL, url.isFileURL {
                    Button("Finder で表示") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
            }
            Circle().fill(.white).overlay(Circle().stroke(.black.opacity(0.75), lineWidth: 0.7))
                .frame(width: 4, height: 4).opacity(running ? 1 : 0)
                .accessibilityHidden(true)
        }
        .padding(vertical ? .vertical : .horizontal, 5)
        .contentShape(Rectangle())
        .anchorPreference(key: DockItemFrames.self, value: .bounds) { [item.id: $0] }
        .onHover { if $0 { hovered = item.id } }
    }
}

private struct DockItemFrames: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct ItemIcon: View {
    let item: DockItem
    var size: Double = 40
    var style: DockAppearance.IconStyle = .original
    var glassNeedsContrast = false
    var glassInteractive = true

    var body: some View {
        Group {
            if let url = item.targetURL, url.isFileURL {
                Image(nsImage: DockIconRenderer.image(url: url, style: style))
                    .resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: item.kind.symbol)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(style == .original ? StudioColor.accent : .white)
                    .opacity(style == .glass ? 0.72 : 1)
                    .frame(width: size, height: size)
                    .background(style == .original ? StudioColor.elevated : Color.white.opacity(style == .glass ? 0 : 0.2),
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
                    Text(context.date, format: .dateTime.month().day().weekday()).font(.caption2).foregroundStyle(StudioColor.muted)
                }
                .frame(width: vertical ? 140 : 125, height: 54)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
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
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
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
    static func length(for store: DockStore) -> CGFloat {
        let vertical = store.document.settings.position != .bottom
        let total = store.displayedItems.reduce(24.0) { sum, item in
            sum + 10 + (item.kind == .spacer ? 11 :
                [.clock, .focusTimer].contains(item.kind) ? (vertical ? 54 : item.kind == .clock ? 125 : 110) : store.effectiveIconSize)
        }
        let reserve = store.appearance.magnification ? store.effectiveIconSize * (store.appearance.magnificationScale - 1) * 3 : 0
        return CGFloat(max(220, total + reserve))
    }
    static func barThickness(for store: DockStore) -> CGFloat {
        CGFloat(store.document.settings.position == .bottom ? max(store.effectiveIconSize, 54) + 30 :
                    max(174, store.effectiveIconSize * (store.appearance.magnification ? store.appearance.magnificationScale : 1) + 32))
    }
    static func thickness(for store: DockStore) -> CGFloat {
        let maximum = store.appearance.magnification ? store.appearance.magnificationScale : 1
        return store.document.settings.position == .bottom ? CGFloat(max(store.effectiveIconSize * maximum, 54) + 65) : barThickness(for: store)
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
