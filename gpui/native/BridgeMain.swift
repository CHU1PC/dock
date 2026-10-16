import AppKit
import Foundation
import Darwin

struct BridgeRequest: Decodable {
    var action: String
    var editingProfileID: UUID?
    var id: UUID?
    var name: String?
    var draftName: String?
    var exitAfter: Bool?
    var kind: DockItemKind?
    var target: String?
    var offset: Int?
    var profile: DockProfile?
    var settings: DockSettings?
    var restoreSettings: Bool?
}

struct BridgeResponse: Encodable {
    var document: DockDocument
    var editorProfile: DockProfile
    var hasUnsavedChanges: Bool
    var hasPendingDrafts: Bool
    var canUndoRemoval: Bool
    var readOnly: Bool
    var exclusive: Bool
    var error: String?
    var status: String
    var backgroundPath: String?
    var displayedItems: [DockItem]
    var runningItemIDs: [String]
    var readOnlyReason: String?
    var icons: [String: String]
    var runningIdentities: [String]
    var runningItems: [DockItem]
    var displays: [BridgeDisplay]
    var pendingImport: [DockProfile]?
    var reduceMotion: Bool
    var reduceTransparency: Bool
}

struct BridgeDisplay: Encodable {
    var id: UInt32
    var name: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

@MainActor
final class BridgeServer {
    let store: DockStore
    let iconDirectory: URL
    var icons: [String: String] = [:]
    private var lockDescriptor: Int32 = -1
    private var ownsLock = false
    private var legacyWasRunning = false
    private var backgroundPath: String?
    private var compatibilityReason: String?
    private var iconSignatures: [String: String] = [:]

    init() {
        let directory = ProcessInfo.processInfo.environment["DOCKSTUDIO_DATA_DIR"].map { URL(fileURLWithPath: $0) }
            ?? ProfilePersistence.applicationDefault.fileURL.deletingLastPathComponent()
        store = DockStore(persistence: ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json")))
        iconDirectory = directory.appendingPathComponent("icon-cache", isDirectory: true)
        if let data = try? Data(contentsOf: directory.appendingPathComponent("profiles.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let settings = json["settings"] as? [String: Any] {
            let known: Set<String> = ["mode", "position", "iconSize", "autoHide", "showRunningApps", "displayID"]
            if !Set(settings.keys).isSubset(of: known) { compatibilityReason = "新しい版の設定項目があります。元のファイルを保護するため、対応する版で開いてください。" }
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            lockDescriptor = open(directory.appendingPathComponent(".gpui-session.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
            if lockDescriptor >= 0 { ownsLock = flock(lockDescriptor, LOCK_EX | LOCK_NB) == 0 }
        } catch { store.errorMessage = "Unable to lock the configuration directory: \(error.localizedDescription)" }
    }

    deinit { if lockDescriptor >= 0 { close(lockDescriptor) } }

    private var legacyIsRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "app.dockstudio.preview" || ($0.bundleIdentifier == nil && $0.executableURL?.lastPathComponent == "DockStudio") }
    }

    func handle(_ request: BridgeRequest) async {
        backgroundPath = nil
        if !ownsLock && request.action == "retry", lockDescriptor >= 0 {
            ownsLock = flock(lockDescriptor, LOCK_EX | LOCK_NB) == 0
            if ownsLock { store.retryLoad() }
        }
        if compatibilityReason != nil && !["snapshot", "poll", "running", "reveal", "open"].contains(request.action) {
            store.errorMessage = "The configuration contains settings from a newer version. Saving is disabled."
            respond(); return
        }
        let legacy = legacyIsRunning
        if legacyWasRunning && !legacy { store.retryLoad() }
        legacyWasRunning = legacy
        if !ownsLock || legacy {
            store.errorMessage = legacy ? "The legacy Dock Studio is running. Close it before editing profiles." : "Another Dock Studio session owns the configuration. Close it before editing."
            if !["snapshot", "poll", "running", "retry", "reveal", "background", "open"].contains(request.action) { respond(); return }
        }
        if !ownsLock || legacy, ["snapshot", "poll", "running", "retry"].contains(request.action) { respond(); return }
        let needsDialog = ["import", "export", "background"].contains(request.action)
            || (request.action == "delete" && store.document.profiles.count > 1)
            || (request.action == "add" && request.kind.map { [.application, .file, .folder].contains($0) } == true)
            || (request.action == "open" && (store.activeProfile.items + store.runningItems).first(where: { $0.id == request.id })?.requiresLaunchConfirmation == true)
        let previousApp = needsDialog ? NSWorkspace.shared.frontmostApplication : nil
        if needsDialog { NSApp.activate(ignoringOtherApps: true) }
        defer {
            if needsDialog && NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
                previousApp?.activate(options: [])
            }
        }
        if let id = request.editingProfileID, store.document.profiles.contains(where: { $0.id == id }) { store.editingProfileID = id }
        if request.exitAfter == true || !["snapshot", "poll", "running"].contains(request.action) { store.errorMessage = nil }
        if ownsLock && !legacy, let name = request.draftName, name != store.editorProfile.name {
            var profile = store.editorProfile
            profile.name = name
            store.editorProfile = profile
        }
        if store.storageIsReadOnly && !["snapshot", "poll", "running", "retry", "reveal", "background", "open"].contains(request.action) {
            store.errorMessage = DockDataError.readOnly.localizedDescription
            respond()
            return
        }
        switch request.action {
        case "snapshot", "poll", "running": break
        case "select":
            if let id = request.id, store.document.profiles.contains(where: { $0.id == id }) { store.editingProfileID = id }
        case "activate": if let id = request.id { store.activateProfile(id) }
        case "create": store.createProfile()
        case "duplicate": store.duplicateProfile()
        case "delete":
            if store.document.profiles.count <= 1 { store.errorMessage = "The final profile cannot be deleted." }
            else if confirm("プロファイルを削除しますか？", detail: "「\(store.editorProfile.name)」の項目と未保存の編集が削除されます。アプリ本体や参照先のファイルは削除されません。") { store.deleteProfile() }
        case "edit": if let profile = request.profile { store.editorProfile = profile }
        case "rename": if let name = request.name { var profile = store.editorProfile; profile.name = name; store.editorProfile = profile }
        case "save": _ = store.saveProfile(activate: request.restoreSettings == true)
        case "saveAll": _ = store.saveAllDrafts()
        case "add":
            if let kind = request.kind {
                if [.application, .file, .folder].contains(kind) { store.chooseItems(kind: kind) }
                else if kind == .link {
                    let name = (request.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let target = (request.target ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty, let url = URL(string: target), let scheme = url.scheme,
                       ["https", "http"].contains(scheme), let host = url.host, !host.isEmpty {
                        store.addItem(DockItem(name: name, kind: kind, target: target))
                    } else { store.errorMessage = "Enter a name and a valid HTTP or HTTPS URL." }
                } else { store.addItem(DockItem(name: request.name ?? kind.title, kind: kind, target: request.target)) }
            }
        case "move": if let id = request.id, let offset = request.offset { store.moveItem(id, by: offset) }
        case "remove": if let id = request.id { store.removeItem(id) }
        case "undo": store.undoRemoval()
        case "settings": if let settings = request.settings { _ = store.updateSettings(settings) }
        case "open":
            if let id = request.id, let item = (store.activeProfile.items + store.runningItems).first(where: { $0.id == id }) { store.openItem(item) }
        case "nativeImport": await store.importCurrentDock()
        case "export": store.exportProfiles()
        case "import": store.importProfiles()
        case "confirmImport": store.confirmImport(restoreSettings: request.restoreSettings == true)
        case "cancelImport": store.pendingImport = nil
        case "retry": store.retryLoad()
        case "reveal": store.revealConfiguration()
        case "background":
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.png, .jpeg, .webP]
            panel.allowsMultipleSelection = false
            panel.level = .modalPanel
            if panel.runModal() == .OK { backgroundPath = panel.url?.path }
        default: store.errorMessage = "Unknown bridge action."
        }
        if request.exitAfter == true, request.action == "snapshot", store.draftRecoveryFailed {
            store.errorMessage = "Recovery drafts could not be saved. Save all edits before quitting."
        }
        respond()
    }

    private func confirm(_ title: String, detail: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")
        alert.window.level = .modalPanel
        return alert.runModal() == .alertFirstButtonReturn
    }

    func respond() {
        var seen: Set<String> = []
        let previous = store.runningItems
        store.runningItems = NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, app.bundleIdentifier != "app.dockstudio.gpui", app.processIdentifier != Int32(ProcessInfo.processInfo.environment["DOCKSTUDIO_UI_PID"] ?? "-1"), let url = app.bundleURL else { return nil }
            let item = DockItem(name: app.localizedName ?? url.deletingPathExtension().lastPathComponent,
                                kind: .application, target: url.absoluteString, bundleIdentifier: app.bundleIdentifier)
            guard let identity = item.applicationIdentity, seen.insert(identity).inserted else { return nil }
            return previous.first(where: { $0.applicationIdentity == identity }) ?? item
        }
        let cacheItems = store.document.profiles.flatMap(\.items) + store.editorProfile.items + store.runningItems
        let validIDs = Set(cacheItems.map { $0.id.uuidString })
        for id in Array(icons.keys) where !validIDs.contains(id) {
            if let path = icons.removeValue(forKey: id) { try? FileManager.default.removeItem(atPath: path) }
            iconSignatures.removeValue(forKey: id)
        }
        for item in cacheItems {
            if let url = item.targetURL, url.isFileURL {
                let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
                let values = try? canonical.resourceValues(forKeys: [.contentModificationDateKey])
                let signature = canonical.path + String(describing: values?.contentModificationDate)
                if icons[item.id.uuidString] != nil && iconSignatures[item.id.uuidString] == signature { continue }
                do {
                    try FileManager.default.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
                    let image = NSWorkspace.shared.icon(forFile: url.path)
                    image.size = NSSize(width: 128, height: 128)
                    var rect = NSRect(x: 0, y: 0, width: 128, height: 128)
                    if let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
                       let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
                        let path = iconDirectory.appendingPathComponent(item.id.uuidString + ".png")
                        try data.write(to: path, options: .atomic)
                        icons[item.id.uuidString] = path.path
                        iconSignatures[item.id.uuidString] = signature
                    }
                } catch { store.status = "Some icons could not be cached: \(error.localizedDescription)" }
            }
        }
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let displays = NSScreen.screens.compactMap { screen -> BridgeDisplay? in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return nil }
            let rect = screen.visibleFrame
            return BridgeDisplay(id: id, name: screen.localizedName, x: rect.minX,
                                 y: mainHeight - rect.maxY, width: rect.width, height: rect.height)
        }
        let response = BridgeResponse(document: store.document, editorProfile: store.editorProfile,
                                      hasUnsavedChanges: store.hasUnsavedChanges, hasPendingDrafts: store.hasPendingDrafts,
                                      canUndoRemoval: store.canUndoRemoval, readOnly: store.storageIsReadOnly || !ownsLock || legacyIsRunning || compatibilityReason != nil, exclusive: ownsLock && !legacyIsRunning && compatibilityReason == nil,
                                      error: store.errorMessage, status: store.status, backgroundPath: backgroundPath,
                                      displayedItems: store.displayedItems,
                                      runningItemIDs: store.displayedItems.filter { $0.applicationIdentity.map(seen.contains) ?? false }.map { $0.id.uuidString },
                                      readOnlyReason: compatibilityReason ?? (!ownsLock ? "別の Dock Studio が設定を使用しています。終了してから読み込み直してください。" : legacyIsRunning ? "旧版の Dock Studio が起動しています。旧版を終了してから読み込み直してください。" : store.storageIsReadOnly ? "設定を読み込めないため、保存を停止しています。元のファイルは保護されています。" : nil),
                                      icons: icons,
                                      runningIdentities: Array(seen), runningItems: store.runningItems, displays: displays,
                                      pendingImport: store.pendingImport?.document.profiles,
                                      reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                                      reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
        do {
            let data = try JSONEncoder().encode(response)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data([10]))
        } catch {
            FileHandle.standardError.write(Data("Bridge encoding failed: \(error)\n".utf8))
        }
    }
}

@main
struct BridgeMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let server = BridgeServer()
        DispatchQueue.global().async {
            while let line = readLine() {
                do {
                    let request = try JSONDecoder().decode(BridgeRequest.self, from: Data(line.utf8))
                    if request.action == "cancel" {
                        DispatchQueue.main.async {
                            if NSApp.modalWindow != nil {
                                NSApp.abortModal()
                                for window in NSApp.windows { window.orderOut(nil) }
                            }
                        }
                    } else { DispatchQueue.main.async { Task { await server.handle(request) } } }
                } catch {
                    FileHandle.standardError.write(Data("Invalid bridge request: \(error)\n".utf8))
                    FileHandle.standardOutput.write(Data("{\"protocolError\":\"Invalid bridge request\"}\n".utf8))
                }
            }
            DispatchQueue.main.async { app.terminate(nil) }
        }
        app.run()
    }
}
