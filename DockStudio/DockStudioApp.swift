import SwiftUI

@main
@MainActor
struct DockStudioApp: App {
    @NSApplicationDelegateAdaptor(DockAppDelegate.self) private var appDelegate
    @State private var store: DockStore
    @State private var dockController: CustomDockWindowController?
    private let tileOnly = ProcessInfo.processInfo.arguments.contains("--native-dock-tile")

    init() {
        let directory = ProcessInfo.processInfo.environment["DOCKSTUDIO_DATA_DIR"]
        let persistence = directory.map {
            ProfilePersistence(fileURL: URL(fileURLWithPath: $0).appendingPathComponent("profiles.json"))
        } ?? .applicationDefault
        let preview = tileOnly ? NativeDockTilePreview(persistence: persistence) : nil
        let store = preview?.store ?? DockStore(persistence: persistence)
        _store = State(initialValue: store)
        appDelegate.store = store
        appDelegate.tileOnly = tileOnly
        appDelegate.tileNotice = preview?.notice ?? ""
    }

    var body: some Scene {
        Window("Dock Studio", id: "studio") {
            PreviewWorkspace()
                .environment(store)
                .task {
                    if dockController == nil { dockController = CustomDockWindowController(store: store) }
                }
        }
        .defaultSize(width: 1080, height: 700)
        .defaultLaunchBehavior(tileOnly ? .suppressed : .automatic)
        .restorationBehavior(tileOnly ? .disabled : .automatic)
        .commands {
            CommandMenu("Custom Dock") {
                Button("Custom Dock の表示を切り替える") { store.toggleDockVisibility() }
                    .disabled(store.storageIsReadOnly)
            }
        }

        MenuBarExtra("Dock Studio", systemImage: "square.stack.3d.up.fill", isInserted: .constant(!tileOnly)) {
            DockMenu()
                .environment(store)
        }
    }
}
