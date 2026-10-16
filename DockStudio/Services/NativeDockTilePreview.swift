import Foundation

@MainActor
struct NativeDockTilePreview {
    let store: DockStore
    let notice: String

    init(persistence: ProfilePersistence) {
        do {
            if let document = try persistence.load() {
                store = DockStore(persistence: nil, initial: document)
                notice = "保存済みプロファイルの試用です。選択は保存せず、Dock の配置も変更しません。"
            } else {
                store = .preview()
                notice = "保存済み設定がないため、サンプルを表示しています。Dock の配置は変更しません。"
            }
        } catch {
            store = .preview()
            notice = "設定を読み込めないため、サンプルを表示しています。元のファイルは変更しません。\n\(error.localizedDescription)"
        }
    }
}
