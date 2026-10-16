import SwiftUI

struct ImportReviewSheet: View {
    @Environment(DockStore.self) private var store
    let pending: PendingProfileImport
    @State private var restoreSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("読み込む内容を確認").font(.title2.weight(.semibold))
            Text("信頼できるプロファイルだけを追加してください。読み込んだアプリやファイルを開く際にも、実際の対象を確認します。")
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(pending.document.profiles) { profile in
                        Text(profile.name).font(.headline)
                        ForEach(profile.items) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(item.name) — \(item.kind.title)")
                                if [.application, .folder, .file, .link].contains(item.kind) {
                                    Text(item.targetURL.map { $0.isFileURL ? $0.path : $0.absoluteString } ?? "この Mac では未設定です。追加し直してください。")
                                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                }
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 280)
            Toggle("設定と使用中のプロファイルも復元する", isOn: $restoreSettings)
            Text(restoreSettings ? "Dock の配置、大きさ、自動非表示などの設定を、読み込んだ設定で上書きします。"
                 : "現在の設定を保ち、プロファイルを新しいコピーとして追加します。")
                .font(.caption).foregroundStyle(.secondary)
            if let error = store.errorMessage { Text(error).foregroundStyle(.red).font(.caption) }
            HStack {
                Button("キャンセル") { store.pendingImport = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(restoreSettings ? "追加して設定を復元" : "プロファイルを追加") {
                    store.confirmImport(restoreSettings: restoreSettings)
                }.buttonStyle(.borderedProminent)
            }
        }.padding(25).frame(width: 560)
    }
}
