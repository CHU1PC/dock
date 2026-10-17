import SwiftUI

struct PreviewWorkspace: View {
    @Environment(DockStore.self) private var store
    @State private var selection: PreviewSection = .dock

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill").foregroundStyle(StudioColor.accent)
                Text("Dock Studio").fontWeight(.semibold)
                Spacer()
                Picker("画面", selection: $selection) {
                    ForEach(PreviewSection.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 390)
                Button {
                    store.toggleDockVisibility()
                } label: {
                    Image(systemName: "dock.rectangle")
                        .foregroundStyle(store.isDockEffectivelyVisible ? StudioColor.accent : Color.primary)
                }
                .help(store.isDockEffectivelyVisible ? "デスクトップの Dock を隠す" : "デスクトップに Dock を表示")
                .accessibilityLabel("デスクトップの Dock を切り替え")
                .disabled(store.storageIsReadOnly)
            }
            .padding(.horizontal, 22)
            .frame(height: 54)
            .background(StudioColor.chrome)
            .zIndex(1)

            if store.storageIsReadOnly {
                VStack(alignment: .leading, spacing: 8) {
                    Label(store.isUsingFallbackData ? "設定を読み込めないため、初期サンプルを表示しています。保存と書き出しは停止中です。"
                          : "下書きを読み込めませんでした。元のファイルを保護するため、保存と書き出しは停止中です。", systemImage: "exclamationmark.triangle")
                    HStack {
                        Button("元の設定ファイルを表示") { store.revealConfiguration() }
                        Button("読み込み直す") { store.retryLoad() }
                    }
                }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Color.orange.opacity(0.15))
            }
            Group {
                switch selection {
                case .dock: CustomDockPreview()
                case .settings: SettingsPreview()
                case .profiles: ProfileEditorPreview()
                }
            }.disabled(store.storageIsReadOnly)
        }
        .frame(minWidth: 900, minHeight: 640)
        .preferredColorScheme(.dark)
        .sheet(item: $store.pendingImport) { ImportReviewSheet(pending: $0).environment(store) }
        .alert("操作を完了できませんでした", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("閉じる", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}

struct DockMenu: View {
    @Environment(DockStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("使用するプロファイル")
        ForEach(store.document.profiles) { profile in
            Button {
                store.activateProfile(profile.id)
            } label: {
                if profile.id == store.document.activeProfileID { Label(profile.name, systemImage: "checkmark") }
                else { Text(profile.name) }
            }.disabled(store.storageIsReadOnly)
        }
        Divider()
        Button(store.isDockEffectivelyVisible ? "Custom Dock を隠す" : "Custom Dock を表示") { store.toggleDockVisibility() }
            .disabled(store.storageIsReadOnly)
        Button("Dock をキーボードで操作") { store.focusDock() }
            .disabled(store.storageIsReadOnly)
        Button("Dock を管理…") {
            openWindow(id: "studio")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("終了") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }
}

enum PreviewSection: String, CaseIterable, Identifiable {
    case dock, settings, profiles
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dock: "Custom Dock"
        case .settings: "設定"
        case .profiles: "プロファイル"
        }
    }
}

enum StudioColor {
    static let chrome = Color(red: 0.075, green: 0.086, blue: 0.12)
    static let surface = Color(red: 0.105, green: 0.12, blue: 0.16)
    static let elevated = Color(red: 0.15, green: 0.17, blue: 0.22)
    static let accent = Color(red: 0.48, green: 0.67, blue: 0.98)
    static let muted = Color(red: 0.6, green: 0.64, blue: 0.72)
}

#Preview("画面を切り替える") {
    PreviewWorkspace().environment(DockStore.preview()).frame(width: 1080, height: 700)
}
