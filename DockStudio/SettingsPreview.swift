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
                    case .appearance: appearanceSettings
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
                    Slider(value: Binding(get: { store.effectiveIconSize }, set: { store.stageIconSize($0) }), in: DockSettings.iconSizeRange, step: 2, onEditingChanged: { if !$0 { store.finishIconSizeEditing() } })
                        .accessibilityLabel("アイコンの大きさ")
                    Text("\(Int(store.effectiveIconSize)) px").monospacedDigit()
                        .foregroundStyle(StudioColor.muted).frame(width: 52, alignment: .trailing)
                }
            }
            settingsGroup("動作") {
                Toggle("使用していないときに隠す", isOn: setting(\.autoHide))
                Text("デスクトップの Dock が隠れたら、画面端にポインタを移すと表示します。")
                    .font(.caption).foregroundStyle(StudioColor.muted)
                HStack {
                    Text("表示アニメーションの時間")
                    Slider(value: Binding(get: { store.effectiveRevealAnimationDuration },
                                          set: { store.stageRevealAnimationDuration($0) }),
                           in: 0...1, step: 0.01,
                           onEditingChanged: { if !$0 { store.finishRevealAnimationDurationEditing() } })
                        .accessibilityLabel("表示アニメーションの時間")
                        .accessibilityValue(String(format: "%.2f秒", store.effectiveRevealAnimationDuration))
                    Text(String(format: "%.2f秒", store.effectiveRevealAnimationDuration))
                        .monospacedDigit().frame(width: 58, alignment: .trailing)
                }
                .disabled(!store.document.settings.autoHide)
                Text("0〜1秒で調整できます。0秒にすると、画面端で即時に表示します。")
                    .font(.caption).foregroundStyle(StudioColor.muted)
                Divider()
                Toggle("起動中にアイコンを跳ねさせる", isOn: setting(\.launchBounce))
                Text("Custom Dock から開いたアプリが起動を終えるまで跳ねます。「アニメーションを減らす」が有効なときは跳ねません。")
                    .font(.caption).foregroundStyle(StudioColor.muted)
                Divider()
                Toggle("実行中のアプリを表示", isOn: setting(\.showRunningApps))
                Divider()
                Toggle("最小化したウインドウをアプリアイコンにまとめる",
                       isOn: setting(\.minimizeWindowsIntoAppIcon))
                Text("有効にすると、アプリのアイコンのメニューから復元するウインドウを選べます。Apple Dock のシステム設定には影響しません。")
                    .font(.caption).foregroundStyle(StudioColor.muted)
                Divider()
                Toggle("最近使ったアプリを表示", isOn: setting(\.showRecentApps))
                Text("固定済みと実行中のアプリを除き、最近使ったアプリを最大3件表示します。オフにすると履歴を消去します。")
                    .font(.caption).foregroundStyle(StudioColor.muted)
            }
            settingsGroup("グローバルショートカット") {
                Picker("Dock にフォーカス", selection: setting(\.dockFocusShortcut)) {
                    ForEach(DockFocusShortcut.allCases) { shortcut in
                        Text(shortcut.title).tag(shortcut)
                    }
                }
                .frame(maxWidth: 260, alignment: .leading)
                Text("どのアプリを使っていても Custom Dock にフォーカスします。Control+Option+Command を使うため、Control+F3 など macOS 標準の Dock 操作キーは変更しません。アクセシビリティの許可は不要です。")
                    .font(.caption).foregroundStyle(StudioColor.muted)
                Text("別のアプリや macOS が選んだキーを使っている場合は登録できません。キーを選び直してください。")
                    .font(.caption).foregroundStyle(StudioColor.muted)
                if let message = store.dockFocusShortcutMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange)
                }
            }
        }
    }

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text("Dock 自体の背景とアイコンを設定します。デスクトップの壁紙は変わりません。")
                .foregroundStyle(StudioColor.muted)
            if let error = store.appearanceLoadError {
                VStack(alignment: .leading, spacing: 10) {
                    Label(error, systemImage: "exclamationmark.triangle")
                    Button("外観設定を読み込み直す") { store.retryAppearance() }
                }.padding().background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 25) {
                settingsGroup("Dock の背景") {
                    Picker("背景", selection: appearance(\.background)) {
                        ForEach(DockAppearance.Background.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    if store.appearance.background == .color {
                        ColorPicker("背景色", selection: Binding(get: {
                            let value = store.appearance.color
                            return Color(red: Double((value >> 16) & 255) / 255,
                                         green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
                        }, set: { color in
                            guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return }
                            var next = store.appearance
                            next.color = UInt32((rgb.redComponent * 255).rounded()) << 16
                                | UInt32((rgb.greenComponent * 255).rounded()) << 8
                                | UInt32((rgb.blueComponent * 255).rounded())
                            store.stageAppearance(\.color, value: next.color)
                        }), supportsOpacity: false)
                    }
                    if store.appearance.background == .image {
                        HStack {
                            Button(store.isChoosingDockBackground ? "画像を読み込み中…" : "背景画像を選ぶ…") { store.chooseDockBackground() }.disabled(store.isChoosingDockBackground)
                            Text(store.appearance.image == nil ? "画像が選択されていません" : "選択した画像を使用中")
                                .font(.caption).foregroundStyle(StudioColor.muted)
                        }
                        Text("選んだ画像はアプリの保存先へコピーします。")
                            .font(.caption).foregroundStyle(StudioColor.muted)
                    }
                    if store.appearance.background == .appleDock {
                        Text("標準の Dock に近い背景です。不透明度とぼかしは、macOS の素材に合わせて自動調整されます。")
                            .font(.caption).foregroundStyle(StudioColor.muted)
                    } else if store.appearance.background != .transparent {
                        HStack {
                            Text("不透明度")
                            Slider(value: stagedAppearance(\.opacity), in: 0...1, step: 0.05, onEditingChanged: { if !$0 { store.finishAppearanceEditing() } })
                                .accessibilityLabel("Dock の背景の不透明度")
                            Text("\(Int(store.appearance.opacity * 100))%")
                                .monospacedDigit().frame(width: 45)
                        }
                        Toggle("背景をぼかす", isOn: appearance(\.blur))
                    } else {
                        Text("背景と輪郭を消し、アイコンだけを表示します。")
                            .font(.caption).foregroundStyle(StudioColor.muted)
                    }
                }
                settingsGroup("Dock の明るさ") {
                    Picker("明るさ", selection: appearance(\.colorMode)) {
                        ForEach(DockAppearance.ColorMode.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    Text("「システムに合わせる」では、macOS のライトとダークの切り替えに Dock が従います。選んだ単色と画像の色は変えません。")
                        .font(.caption).foregroundStyle(StudioColor.muted)
                }
                settingsGroup("アイコン") {
                    Picker("アイコンの外観", selection: appearance(\.iconStyle)) {
                        ForEach(DockAppearance.IconStyle.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    Text("ガラス調は、透ける素材に元のアイコンの絵柄を重ねます。背景の色と光を取り込んだ表現になります。")
                        .font(.caption).foregroundStyle(StudioColor.muted)
                    Divider()
                    Toggle("起動中のアプリに点を表示", isOn: appearance(\.runningIndicators))
                }
                settingsGroup("ホバーとアニメーション") {
                    Toggle("ポインタを重ねたアイコンを拡大", isOn: appearance(\.magnification))
                    if store.appearance.magnification {
                        HStack {
                            Text("拡大率")
                            Slider(value: stagedAppearance(\.magnificationScale), in: 1...2, step: 0.05, onEditingChanged: { if !$0 { store.finishAppearanceEditing() } })
                                .accessibilityLabel("アイコンの拡大率")
                            Text(String(format: "%.2f×", store.appearance.magnificationScale)).monospacedDigit()
                        }
                    }
                    Toggle("アニメーションを減らす", isOn: appearance(\.reduceMotion))
                    Text("macOS の「視差効果を減らす」も反映します。")
                        .font(.caption).foregroundStyle(StudioColor.muted)
                }
            }.disabled(store.appearanceIsReadOnly)
            Text("外観はすべてのプロファイルに共通です。現在のプロファイル書き出しには含まれません。")
                .font(.caption).foregroundStyle(StudioColor.muted)
        }
    }

    private func stagedAppearance<Value>(_ path: WritableKeyPath<DockAppearance, Value>) -> Binding<Value> {
        Binding(get: { store.appearance[keyPath: path] }, set: { store.stageAppearance(path, value: $0) })
    }

    private func appearance<Value>(_ path: WritableKeyPath<DockAppearance, Value>) -> Binding<Value> {
        Binding(get: { store.appearance[keyPath: path] }, set: { value in
            var next = store.appearance
            next[keyPath: path] = value
            store.updateAppearance(next)
        })
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
            settingsGroup("ログイン時の起動") {
                Toggle("ログイン時に Dock Studio を開く", isOn: Binding(
                    get: { store.loginItem.isOn }, set: { store.loginItem.setEnabled($0) }))
                Text("次回のログインと再起動後に Dock Studio を起動し、前回の Dock の表示状態を復元します。「Dock を隠す」で隠した場合は、隠したままにします。")
                    .font(.caption).foregroundStyle(StudioColor.muted)
                if let message = store.loginItem.message {
                    Label(message, systemImage: "exclamationmark.triangle").font(.callout)
                }
                if store.loginItem.state == .requiresApproval {
                    Button("システム設定を開く") { store.loginItem.openSystemSettings() }
                }
                if let notice = store.launchStateNotice {
                    Label(notice, systemImage: "exclamationmark.triangle").font(.callout)
                }
            }
            settingsGroup("Apple Dock") {
                Text("現在ピン留めされているアプリとスペーサーから、Custom Dock のプロファイルを作成します。")
                    .font(.callout).foregroundStyle(StudioColor.muted)
                Button(store.isReadingNativeDock ? "読み込み中…" : "現在の Apple Dock から取り込む") { Task { await store.importCurrentDock() } }.disabled(store.isReadingNativeDock || store.storageIsReadOnly)
            }
            if !store.status.isEmpty { Text(store.status).foregroundStyle(StudioColor.muted).font(.callout) }
        }
        .onAppear { store.loginItem.refresh() }
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
    case dock, appearance, widgets, general
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dock: "Dock"
        case .appearance: "外観"
        case .widgets: "ウィジェット"
        case .general: "一般"
        }
    }
    var symbol: String {
        switch self {
        case .dock: "dock.rectangle"
        case .appearance: "paintpalette"
        case .widgets: "square.grid.2x2"
        case .general: "gearshape"
        }
    }
}

#Preview("設定") {
    SettingsPreview().environment(DockStore.preview()).frame(width: 940, height: 650)
}
