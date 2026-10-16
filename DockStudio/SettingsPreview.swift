import SwiftUI

struct SettingsPreview: View {
    @Environment(DockStore.self) private var store
    @State private var section: SettingsSection = .dock

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("設定").font(.title2.weight(.semibold)).padding(.bottom, 18)
                ForEach(SettingsSection.allCases) { value in
                    Button { section = value } label: {
                        Label(value.title, systemImage: value.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).frame(height: 36)
                            .background(section == value ? StudioColor.accent.opacity(0.2) : .clear,
                                        in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(section == value ? .white : StudioColor.muted)
                    }.buttonStyle(.plain)
                }
                Spacer()
                Text(store.storageIsReadOnly ? "保存を停止しています" : store.isPreview ? "Xcode Preview" : "変更は自動保存されます")
                    .font(.caption).foregroundStyle(StudioColor.muted)
            }
            .padding(20).frame(width: 220).frame(maxHeight: .infinity, alignment: .topLeading)
            .background(StudioColor.chrome)

            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Text(section.title).font(.system(size: 29, weight: .semibold, design: .rounded))
                    switch section {
                    case .dock: dockSettings
                    case .widgets: widgetSettings
                    case .general: generalSettings
                    }
                }
                .padding(34).frame(maxWidth: 690, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(StudioColor.surface)
        }
        .preferredColorScheme(.dark)
    }

    private var dockSettings: some View {
        Group {
            Text("Apple Dock と Custom Dock の使い方を選びます。")
                .foregroundStyle(StudioColor.muted)
            settingsGroup("表示する Dock") {
                Picker("構成", selection: setting(\.mode)) {
                    ForEach(DockMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(store.document.settings.mode.description).font(.callout).foregroundStyle(StudioColor.muted)
            }
            settingsGroup("Custom Dock の配置") {
                HStack {
                    Text("画面の位置")
                    Spacer()
                    Picker("画面の位置", selection: setting(\.position)) {
                        ForEach(DockPosition.allCases) { Text($0.title).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented).frame(width: 170)
                }
                Divider()
                HStack {
                    Text("表示先")
                    Spacer()
                    Picker("表示先", selection: setting(\.displayID)) {
                        Text("メインディスプレイ").tag(Optional<UInt32>.none)
                        ForEach(store.availableDisplays) { screen in
                            Text(screen.name).tag(Optional(screen.id))
                        }
                        if let selectedID = store.document.settings.displayID,
                           !store.availableDisplays.contains(where: { $0.id == selectedID }) {
                            Text("未接続のディスプレイ").tag(Optional(selectedID))
                        }
                    }.labelsHidden().frame(width: 210)
                }
                Divider()
                HStack(spacing: 20) {
                    Text("アイコンの大きさ")
                    Slider(value: Binding(get: { store.effectiveIconSize }, set: { store.stageIconSize($0) }), in: 40...76, step: 2, onEditingChanged: { if !$0 { store.finishIconSizeEditing() } })
                        .accessibilityLabel("アイコンの大きさ")
                    Text("\(Int(store.effectiveIconSize)) px").monospacedDigit()
                        .foregroundStyle(StudioColor.muted).frame(width: 52, alignment: .trailing)
                }
            }
            settingsGroup("動作") {
                Toggle("使用していないときに隠す", isOn: setting(\.autoHide))
                Text("デスクトップの Dock が隠れたら、画面端にポインタを移すと表示します。")
                    .font(.caption).foregroundStyle(StudioColor.muted)
                Divider()
                Toggle("実行中のアプリを表示", isOn: setting(\.showRunningApps))
            }
        }
    }

    private var widgetSettings: some View {
        settingsGroup("使用できるウィジェット") {
            Label("時計", systemImage: "clock")
            Text("現在の時刻と日付を表示します。クリックすると詳細を開きます。")
                .font(.callout).foregroundStyle(StudioColor.muted)
            Divider()
            Label("集中タイマー", systemImage: "timer")
            Text("25 分の集中時間を計ります。クリックで開始と一時停止、右クリックでリセットできます。")
                .font(.callout).foregroundStyle(StudioColor.muted)
            Divider()
            Text("プロファイル編集の「項目を追加」から Dock に配置できます。")
                .font(.callout).foregroundStyle(StudioColor.muted)
        }
    }

    private var generalSettings: some View {
        Group {
            settingsGroup("バックアップ") {
                Text("保存済みのプロファイルと設定を書き出します。読み込み時に、プロファイルの追加だけか、設定も復元するかを選べます。")
                    .font(.callout).foregroundStyle(StudioColor.muted)
                Text("絶対パスは書き出しません。ホームフォルダの外にあるファイルは、読み込み後に追加し直してください。")
                    .font(.caption).foregroundStyle(StudioColor.muted)
                HStack {
                    Button("書き出す…") { store.exportProfiles() }.disabled(store.storageIsReadOnly)
                    Button("読み込む…") { store.importProfiles() }.disabled(store.storageIsReadOnly)
                }
            }
            settingsGroup("Apple Dock") {
                Text("現在ピン留めされているアプリとスペーサーから、Custom Dock のプロファイルを作成します。")
                    .font(.callout).foregroundStyle(StudioColor.muted)
                Button(store.isReadingNativeDock ? "読み込み中…" : "現在の Apple Dock から取り込む") { Task { await store.importCurrentDock() } }.disabled(store.isReadingNativeDock || store.storageIsReadOnly)
            }
            if !store.status.isEmpty { Text(store.status).foregroundStyle(StudioColor.muted).font(.callout) }
        }
    }

    private func setting<Value>(_ path: WritableKeyPath<DockSettings, Value>) -> Binding<Value> {
        Binding(get: { store.document.settings[keyPath: path] }, set: { value in
            var settings = store.document.settings
            settings[keyPath: path] = value
            store.updateSettings(settings)
        })
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 14, content: content)
                .padding(17).frame(maxWidth: .infinity, alignment: .leading)
                .background(StudioColor.elevated, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case dock, widgets, general
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dock: "Dock"
        case .widgets: "ウィジェット"
        case .general: "一般"
        }
    }
    var symbol: String {
        switch self {
        case .dock: "dock.rectangle"
        case .widgets: "square.grid.2x2"
        case .general: "gearshape"
        }
    }
}

#Preview("設定") {
    SettingsPreview().environment(DockStore.preview()).frame(width: 940, height: 650)
}
