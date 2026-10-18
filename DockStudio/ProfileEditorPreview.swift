import SwiftUI

struct ProfileEditorPreview: View {
    @Environment(DockStore.self) private var store
    @State private var selectedItemID: UUID?
    @State private var showLinkSheet = false
    @State private var confirmDelete = false

    private var selectedIndex: Int? {
        store.editorProfile.items.firstIndex { $0.id == selectedItemID }
    }

    private var selectedItemLocked: Bool {
        guard store.document.settings.finderEntryEnabled,
              let selectedItemID,
              let item = store.editorProfile.items.first(where: { $0.id == selectedItemID }) else { return false }
        return FinderDockEntry.isFinder(item)
    }

    var body: some View {
        @Bindable var store = store
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("プロファイル").font(.title2.weight(.semibold)).padding(.bottom, 15)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.document.profiles) { profile in
                            Button {
                                store.editingProfileID = profile.id
                                selectedItemID = nil
                            } label: {
                                HStack {
                                    Image(systemName: "square.stack.3d.up")
                                    Text(profile.id == store.editingProfileID ? store.editorProfile.name : profile.name)
                                        .lineLimit(1)
                                    Spacer()
                                    if profile.id == store.document.activeProfileID {
                                        Image(systemName: "checkmark").font(.caption)
                                    }
                                }
                                .padding(.horizontal, 12).frame(height: 36)
                                .background(store.editingProfileID == profile.id ? StudioColor.accent.opacity(0.2) : .clear,
                                            in: RoundedRectangle(cornerRadius: 9))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Button {
                    store.createProfile()
                    selectedItemID = nil
                } label: {
                    Label("新しいプロファイル", systemImage: "plus")
                }
                .buttonStyle(.plain).foregroundStyle(StudioColor.accent)
                Menu("プロファイルの操作") {
                    Button("複製") { store.duplicateProfile(); selectedItemID = nil }
                    Button("Apple Dock から取り込む") { Task { await store.importCurrentDock(); selectedItemID = nil } }
                    Divider()
                    Button("削除…", role: .destructive) { confirmDelete = true }
                        .disabled(store.document.profiles.count < 2)
                }.padding(.top, 8)
                Text("Custom Dock").font(.caption).foregroundStyle(StudioColor.muted)
            }
            .padding(20).frame(width: 225).frame(maxHeight: .infinity, alignment: .topLeading)
            .background(StudioColor.chrome)

            VStack(alignment: .leading, spacing: 19) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("プロファイル名", text: $store.editorProfile.name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 25, weight: .semibold, design: .rounded))
                            .accessibilityLabel("プロファイル名")
                        Text(store.hasUnsavedChanges ? "未保存の変更があります" : "保存済み")
                            .font(.callout).foregroundStyle(StudioColor.muted)
                    }
                    Spacer()
                    Button("保存して使用") { store.saveProfile(activate: true) }
                        .buttonStyle(.borderedProminent).tint(StudioColor.accent)
                        .disabled(store.storageIsReadOnly)
                }
                Label("項目を選び、下の矢印で順番を整えます。", systemImage: "info.circle")
                    .font(.callout).foregroundStyle(StudioColor.accent)
                    .padding(15).frame(maxWidth: .infinity, alignment: .leading)
                    .background(StudioColor.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                if store.document.settings.finderEntryEnabled {
                    Text("Finder を先頭に固定中は、Dock上の位置を固定し、Dockからの削除を無効にします。設定で固定を解除すると、削除や並べ替えができます。")
                        .font(.caption).foregroundStyle(StudioColor.muted)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(store.editorProfile.items.enumerated()), id: \.element.id) { index, item in
                            Button { selectedItemID = item.id } label: {
                                HStack(spacing: 15) {
                                    ItemIcon(item: item, size: 32, availability: store.itemAvailability.status(of: item))
                                        .task(id: item.target) { await store.itemAvailability.refresh([item]) }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name).foregroundStyle(.white)
                                        Text(item.kind.title).font(.caption).foregroundStyle(StudioColor.muted)
                                    }
                                    Spacer()
                                    Text("\(index + 1)").monospacedDigit().font(.caption)
                                        .foregroundStyle(StudioColor.muted)
                                }
                                .padding(.horizontal, 17).frame(height: 61)
                                .background(selectedItemID == item.id ? StudioColor.accent.opacity(0.14) : .clear)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(item.name)、\(item.kind.title)")
                            if index < store.editorProfile.items.count - 1 { Divider().padding(.leading, 60) }
                        }
                        if store.editorProfile.items.isEmpty {
                            ContentUnavailableView("項目を追加", systemImage: "plus.circle",
                                                   description: Text("アプリ、フォルダ、ウィジェットを追加できます。"))
                                .frame(minHeight: 160)
                        }
                    }
                }
                .background(StudioColor.elevated, in: RoundedRectangle(cornerRadius: 14))

                HStack {
                    Menu {
                        Button("アプリ…") { store.chooseItems(kind: .application) }
                        Button("フォルダ…") { store.chooseItems(kind: .folder) }
                        Button("ファイル…") { store.chooseItems(kind: .file) }
                        Button("Web リンク…") { showLinkSheet = true }
                        Divider()
                        ForEach([DockItemKind.spacer, .clock, .focusTimer]) { kind in
                            Button(kind.title) { store.addItem(DockItem(name: kind.title, kind: kind)) }
                        }
                    } label: { Label("項目を追加", systemImage: "plus") }
                    Button { if let selectedItemID { store.moveItem(selectedItemID, by: -1) } } label: {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(selectedIndex == nil || selectedIndex == 0 || selectedItemLocked)
                    .accessibilityLabel("上に移動")
                    Button { if let selectedItemID { store.moveItem(selectedItemID, by: 1) } } label: {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(selectedIndex == nil || selectedIndex == store.editorProfile.items.count - 1 || selectedItemLocked)
                    .accessibilityLabel("下に移動")
                    Button {
                        if let selectedItemID { store.removeItem(selectedItemID) }
                        selectedItemID = nil
                    } label: { Image(systemName: "trash") }
                    .disabled(selectedIndex == nil || selectedItemLocked).accessibilityLabel("選択した項目を削除")
                    Spacer()
                    Button("変更を保存") { store.saveProfile() }
                        .buttonStyle(.borderedProminent).tint(StudioColor.accent)
                        .disabled(!store.hasUnsavedChanges || store.storageIsReadOnly)
                }
                HStack {
                    Text(store.status).font(.caption).foregroundStyle(StudioColor.muted).lineLimit(2)
                    Spacer()
                    if store.canUndoRemoval { Button("削除を取り消す") { store.undoRemoval() }.font(.caption) }
                }.frame(height: 26)
            }
            .padding(30).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(StudioColor.surface)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLinkSheet) { AddLinkSheet().environment(store) }
        .confirmationDialog("「\(store.editorProfile.name)」を削除しますか？", isPresented: $confirmDelete) {
            Button("プロファイルを削除", role: .destructive) { store.deleteProfile(); selectedItemID = nil }
        } message: { Text("このプロファイルに保存した項目と、未保存の編集内容が削除されます。ファイルやアプリ本体は削除されません。") }
        .onChange(of: store.editingProfileID) { selectedItemID = nil }
    }
}

private struct AddLinkSheet: View {
    @Environment(DockStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = "https://"
    private var valid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, let url = URL(string: address),
              let scheme = url.scheme, ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty else { return false }
        return true
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Web リンクを追加").font(.title2.weight(.semibold))
            TextField("名前", text: $name).textFieldStyle(.roundedBorder)
            TextField("https://example.com", text: $address).textFieldStyle(.roundedBorder)
            HStack {
                Button("キャンセル") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("追加") {
                    store.addItem(DockItem(name: name.trimmingCharacters(in: .whitespaces), kind: .link, target: address))
                    dismiss()
                }.buttonStyle(.borderedProminent).disabled(!valid).keyboardShortcut(.defaultAction)
            }
        }.padding(25).frame(width: 420)
    }
}

#Preview("プロファイル編集") {
    ProfileEditorPreview().environment(DockStore.preview()).frame(width: 980, height: 660)
}
