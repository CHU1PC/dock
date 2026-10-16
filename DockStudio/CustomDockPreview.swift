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
    let vertical: Bool

    var body: some View {
        ScrollView(vertical ? .vertical : .horizontal) {
            let layout = vertical ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                if store.displayedItems.isEmpty {
                    Label("プロファイルに項目を追加", systemImage: "plus.circle")
                        .font(.callout).foregroundStyle(StudioColor.muted).padding(10)
                }
                ForEach(store.displayedItems) { item in
                    if item.kind == .spacer {
                        Rectangle().fill(.white.opacity(0.2))
                            .frame(width: vertical ? 80 : 1, height: vertical ? 1 : 40)
                            .padding(5)
                    } else if item.kind == .clock {
                        ClockTile(vertical: vertical)
                    } else if item.kind == .focusTimer {
                        FocusTimerTile(itemID: item.id, vertical: vertical)
                    } else {
                        Button { store.openItem(item) } label: {
                            ItemIcon(item: item, size: store.effectiveIconSize)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.name)
                        .help(item.name)
                    }
                }
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.23)))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .preferredColorScheme(.dark)
    }
}

struct ItemIcon: View {
    let item: DockItem
    var size: Double = 40

    var body: some View {
        Group {
            if let url = item.targetURL, url.isFileURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: item.kind.symbol)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(StudioColor.accent)
                    .frame(width: size, height: size)
                    .background(StudioColor.elevated, in: RoundedRectangle(cornerRadius: size * 0.23))
            }
        }
        .frame(width: size, height: size)
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
        return CGFloat(max(220, total))
    }
    static func thickness(for store: DockStore) -> CGFloat {
        CGFloat(store.document.settings.position == .bottom ? max(store.effectiveIconSize, 54) + 24 : 174)
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
