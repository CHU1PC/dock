import SwiftUI

struct DockSeparatorContextMenu: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    let store: DockStore

    func body(content: Content) -> some View {
        content.contextMenu {
            Menu("配置") {
                ForEach(DockPosition.allCases) { position in
                    Button {
                        store.updateSettings(DockSeparatorSettings.position(position, in: store.document.settings))
                    } label: {
                        settingLabel(position.title, selected: store.document.settings.position == position)
                    }
                    .disabled(store.storageIsReadOnly)
                }
            }

            Button {
                store.updateAppearance(DockSeparatorSettings.toggledMagnification(in: store.appearance))
            } label: {
                settingLabel("拡大", selected: store.appearance.magnification)
            }
            .disabled(store.storageIsReadOnly || store.appearanceIsReadOnly)

            Button {
                store.updateSettings(DockSeparatorSettings.toggledAutoHide(in: store.document.settings))
            } label: {
                settingLabel("使用していないときに隠す", selected: store.document.settings.autoHide)
            }
            .disabled(store.storageIsReadOnly)

            Divider()

            Button("Dock 設定を開く…") {
                store.settingsWindowRequested += 1
                openWindow(id: "studio")
            }
        }
    }

    @ViewBuilder
    private func settingLabel(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}

enum DockSeparatorSettings {
    static func position(_ position: DockPosition, in settings: DockSettings) -> DockSettings {
        var updated = settings
        updated.position = position
        return updated
    }

    static func toggledAutoHide(in settings: DockSettings) -> DockSettings {
        var updated = settings
        updated.autoHide.toggle()
        return updated
    }

    static func toggledMagnification(in appearance: DockAppearance) -> DockAppearance {
        var updated = appearance
        updated.magnification.toggle()
        return updated
    }
}
