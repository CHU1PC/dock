import SwiftUI

/// body をサブビューに閉じ込め、DockBar の body の再評価（ホバーのたび）で実行されないようにする。
struct DockItemAccessibilityActionsContent: View {
    let store: DockStore
    let item: DockItem
    let actions: () -> [DockItemAction]

    var body: some View {
        ForEach(actions().filter(\.isAccessibilityAction)) { action in
            Button(action.title, action: action.perform)
                .disabled(!action.isEnabled)
        }
        if item.kind == .application, item.applicationIdentity?.hasPrefix("bundle:") == true {
            ForEach(DockApplicationWindowMenuModel.entries(
                from: store.applicationWindowListing(for: item, promptForAccess: false)), id: \.self) { entry in
                switch entry {
                case .window(let id, let title):
                    Button("ウィンドウを前面に表示: \(title)") { store.activateApplicationWindow(id, for: item) }
                case .unavailable(let title):
                    Button(title) {}.disabled(true)
                }
            }
        }
    }
}

struct DockItemContextMenuContent: View {
    let store: DockStore
    let item: DockItem
    let actions: () -> [DockItemAction]
    let supportsApplicationDockMenu: () -> Bool
    let showApplicationDockMenu: () -> Void

    var body: some View {
        ForEach(actions()) { action in
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
        if supportsApplicationDockMenu() {
            Button("アプリ固有メニュー…") { showApplicationDockMenu() }
        }
    }
}
