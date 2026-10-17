import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class DockStore {
    private(set) var document: DockDocument
    var editingProfileID: UUID
    private var drafts: [UUID: DockProfile] = [:]
    private var removedItem: (profileID: UUID, item: DockItem, index: Int)?
    private(set) var storageIsReadOnly = false
    private(set) var isUsingFallbackData = false
    var errorMessage: String?
    var status = ""
    var isDockVisible = false
    var runningItems: [DockItem] = []
    var availableDisplays = DisplayOption.current
    var focusSessions: [UUID: FocusSession] = [:]
    var activePopoverTokens: Set<UUID> = []
    var pendingImport: PendingProfileImport?
    private(set) var isReadingNativeDock = false
    private(set) var draftRecoveryFailed = false
    private(set) var transientIconSize: Double?
    private(set) var transientRevealAnimationDuration: Double?
    private var savedAppearance = DockAppearance()
    private var transientAppearance: DockAppearance?
    private var appearanceSavedData: Data?
    @ObservationIgnored private var appearanceSaveTask: Task<Void, Never>?
    private(set) var isChoosingDockBackground = false
    var dockKeyboardFocusRequested = false
    var isDockPointerInside = false
    var appearance: DockAppearance { transientAppearance ?? savedAppearance }
    private(set) var appearanceIsReadOnly = false
    var appearanceLoadError: String?
    @ObservationIgnored private var iconSizeSaveTask: Task<Void, Never>?
    @ObservationIgnored private var revealDurationSaveTask: Task<Void, Never>?
    private var hasPersistedDocument = false
    let isPreview: Bool
    private let persistence: ProfilePersistence?

    init(persistence: ProfilePersistence? = .applicationDefault, initial: DockDocument? = nil) {
        self.persistence = persistence
        isPreview = persistence == nil
        let seed = initial ?? Self.initialDocument()
        document = seed
        editingProfileID = seed.activeProfileID
        do {
            if let loaded = try persistence?.load() {
                document = loaded
                editingProfileID = loaded.activeProfileID
                hasPersistedDocument = true
                try restoreDrafts()
            } else if let persistence, FileManager.default.fileExists(atPath: persistence.draftsURL.path) {
                throw DockDataError.invalidData("The saved configuration is missing, but recovery drafts exist.")
            }
        } catch {
            storageIsReadOnly = true
            isUsingFallbackData = !hasPersistedDocument
            errorMessage = "保存済みの設定を読み込めませんでした。元のファイルを保護するため、保存を停止しています。\n\(error.localizedDescription)"
        }
        loadAppearance()
    }

    static func preview() -> DockStore { DockStore(persistence: nil) }

    private var appearanceURL: URL? {
        persistence?.fileURL.deletingLastPathComponent().appendingPathComponent("appearance.json")
    }

    private func loadAppearance() {
        guard let url = appearanceURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            var value = try JSONDecoder().decode(DockAppearance.self, from: data)
            if let path = value.image, !FileManager.default.fileExists(atPath: path) {
                let old = URL(fileURLWithPath: path)
                let moved = url.deletingLastPathComponent().appendingPathComponent("backgrounds").appendingPathComponent(old.lastPathComponent)
                if old.deletingLastPathComponent().lastPathComponent == "backgrounds",
                   UUID(uuidString: old.deletingPathExtension().lastPathComponent) != nil,
                   old.pathExtension == "png", FileManager.default.fileExists(atPath: moved.path) {
                    value.image = moved.path
                }
            }
            savedAppearance = value
            appearanceSavedData = data
        }
        catch {
            appearanceIsReadOnly = true
            appearanceLoadError = "外観設定を読み込めませんでした。元のファイルを保護しています。\n\(error.localizedDescription)"
        }
    }

    func retryAppearance() {
        appearanceIsReadOnly = false
        appearanceLoadError = nil
        appearanceSaveTask?.cancel()
        transientAppearance = nil
        appearanceSavedData = nil
        savedAppearance = DockAppearance()
        loadAppearance()
    }

    @discardableResult
    func updateAppearance(_ next: DockAppearance) -> Bool {
        guard !storageIsReadOnly, !appearanceIsReadOnly else { return false }
        do {
            try next.validate()
            if let url = appearanceURL {
                appearanceSavedData = try DockAppearancePersistence.save(next, to: url, expected: appearanceSavedData)
            }
            appearanceSaveTask?.cancel()
            transientAppearance = nil
            savedAppearance = next
            return true
        } catch {
            if error is DockAppearanceWriteError {
                appearanceIsReadOnly = true
                appearanceLoadError = "外観設定が別のアプリで変更されました。読み込み直してから編集してください。"
            }
            errorMessage = "外観設定を保存できませんでした。\n\(error.localizedDescription)"
            return false
        }
    }

    func stageAppearance<Value>(_ path: WritableKeyPath<DockAppearance, Value>, value: Value) {
        guard !storageIsReadOnly, !appearanceIsReadOnly else { return }
        var next = appearance
        next[keyPath: path] = value
        guard (try? next.validate()) != nil else { return }
        transientAppearance = next
        appearanceSaveTask?.cancel()
        appearanceSaveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) }
            catch { return }
            self?.finishAppearanceEditing()
        }
    }

    @discardableResult
    func finishAppearanceEditing() -> Bool {
        appearanceSaveTask?.cancel()
        appearanceSaveTask = nil
        guard let next = transientAppearance else { return true }
        transientAppearance = nil
        return updateAppearance(next)
    }

    func focusDock() {
        if !isDockEffectivelyVisible { toggleDockVisibility() }
        if isDockEffectivelyVisible { dockKeyboardFocusRequested = true }
    }

    func chooseDockBackground() {
        guard !storageIsReadOnly, !appearanceIsReadOnly, !isChoosingDockBackground,
              finishAppearanceEditing() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }
        isChoosingDockBackground = true
        let directory = appearanceURL?.deletingLastPathComponent()
        Task { [weak self] in
            do {
                let path = try await Task.detached(priority: .userInitiated) {
                    try DockBackgroundAssets.importImage(sourceURL, directory: directory)
                }.value
                guard let self else { DockBackgroundAssets.removeManagedImage(path, directory: directory); return }
                let previous = self.appearance.image
                var next = self.appearance
                next.background = .image
                next.image = path
                if self.updateAppearance(next) {
                    if previous != path { DockBackgroundAssets.removeManagedImage(previous, directory: directory) }
                } else { DockBackgroundAssets.removeManagedImage(path, directory: directory) }
            } catch {
                self?.errorMessage = "背景画像を読み込めませんでした。\n\(error.localizedDescription)"
            }
            self?.isChoosingDockBackground = false
        }
    }

    var activeProfile: DockProfile {
        document.profiles.first { $0.id == document.activeProfileID } ?? document.profiles[0]
    }

    var editorProfile: DockProfile {
        get {
            drafts[editingProfileID] ?? document.profiles.first { $0.id == editingProfileID } ?? activeProfile
        }
        set {
            guard !storageIsReadOnly, newValue.id == editingProfileID else { return }
            drafts[editingProfileID] = newValue
            persistDrafts()
        }
    }

    var hasUnsavedChanges: Bool {
        document.profiles.first { $0.id == editingProfileID } != editorProfile
    }

    var canUndoRemoval: Bool { removedItem?.profileID == editingProfileID }

    var displayedItems: [DockItem] {
        guard document.settings.showRunningApps else { return activeProfile.items }
        var seen = Set(activeProfile.items.compactMap(\.applicationIdentity))
        return activeProfile.items + runningItems.filter { item in
            guard let identity = item.applicationIdentity else { return false }
            return seen.insert(identity).inserted
        }
    }

    @discardableResult
    private func commit(_ candidate: DockDocument) -> Bool {
        do {
            guard !storageIsReadOnly else { throw DockDataError.readOnly }
            try candidate.validate()
            try persistence?.save(candidate)
            document = candidate
            hasPersistedDocument = true
            return true
        } catch {
            errorMessage = "変更を保存できませんでした。\n\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func saveProfile(activate: Bool = false) -> Bool {
        var candidate = document
        guard let index = candidate.profiles.firstIndex(where: { $0.id == editingProfileID }) else { return false }
        var profile = editorProfile
        profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profile.name.isEmpty else {
            errorMessage = "プロファイル名を入力してください。"
            return false
        }
        candidate.profiles[index] = profile
        if activate { candidate.activeProfileID = profile.id }
        if commit(candidate) {
            drafts[profile.id] = nil
            persistDrafts()
            status = activate ? "\(profile.name) を保存して使用しています" : "\(profile.name) を保存しました"
            return true
        }
        return false
    }

    func activateProfile(_ id: UUID) {
        var candidate = document
        candidate.activeProfileID = id
        if commit(candidate) { status = "\(activeProfile.name) を使用しています" }
    }

    func createProfile() {
        let profile = DockProfile(name: uniqueName("新しい Dock"), items: [])
        var candidate = document
        candidate.profiles.append(profile)
        if commit(candidate) { editingProfileID = profile.id; removedItem = nil }
    }

    func duplicateProfile() {
        var profile = editorProfile
        profile.id = UUID()
        profile.name = uniqueName("\(profile.name) のコピー")
        profile.items = profile.items.map { item in var copy = item; copy.id = UUID(); return copy }
        var candidate = document
        candidate.profiles.append(profile)
        if commit(candidate) { editingProfileID = profile.id; removedItem = nil }
    }

    func deleteProfile() {
        guard document.profiles.count > 1 else { return }
        let deletedID = editingProfileID
        var candidate = document
        candidate.profiles.removeAll { $0.id == deletedID }
        if candidate.activeProfileID == deletedID { candidate.activeProfileID = candidate.profiles[0].id }
        if commit(candidate) {
            drafts[deletedID] = nil
            persistDrafts()
            editingProfileID = candidate.activeProfileID
            removedItem = nil
        }
    }

    @discardableResult
    func updateSettings(_ settings: DockSettings) -> Bool {
        var candidate = document
        candidate.settings = settings
        guard commit(candidate) else { return false }
        if settings.mode == .native { isDockVisible = false }
        return true
    }

    var effectiveIconSize: Double { transientIconSize ?? document.settings.iconSize }
    var effectiveRevealAnimationDuration: Double { transientRevealAnimationDuration ?? document.settings.revealAnimationDuration }
    var isDockEffectivelyVisible: Bool { isDockVisible && document.settings.mode != .native }
    var hasPendingDrafts: Bool {
        drafts.values.contains { draft in document.profiles.first(where: { $0.id == draft.id }) != draft }
    }

    func toggleDockVisibility() {
        guard !storageIsReadOnly else { return }
        if isDockEffectivelyVisible { isDockVisible = false; return }
        if document.settings.mode == .native {
            var candidate = document
            candidate.settings.mode = .both
            guard commit(candidate) else { return }
        }
        isDockVisible = true
    }

    func stageIconSize(_ size: Double) {
        guard !storageIsReadOnly else { return }
        transientIconSize = size
        iconSizeSaveTask?.cancel()
        iconSizeSaveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) }
            catch { return }
            self?.finishIconSizeEditing()
        }
    }

    @discardableResult
    func finishIconSizeEditing() -> Bool {
        iconSizeSaveTask?.cancel()
        iconSizeSaveTask = nil
        guard let size = transientIconSize else { return true }
        transientIconSize = nil
        var settings = document.settings
        settings.iconSize = size
        return updateSettings(settings)
    }

    func stageRevealAnimationDuration(_ duration: Double) {
        guard !storageIsReadOnly, duration.isFinite else { return }
        transientRevealAnimationDuration = min(1, max(0, (duration * 100).rounded() / 100))
        revealDurationSaveTask?.cancel()
        revealDurationSaveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) }
            catch { return }
            self?.finishRevealAnimationDurationEditing()
        }
    }

    @discardableResult
    func finishRevealAnimationDurationEditing() -> Bool {
        revealDurationSaveTask?.cancel()
        revealDurationSaveTask = nil
        guard let duration = transientRevealAnimationDuration else { return true }
        transientRevealAnimationDuration = nil
        var settings = document.settings
        settings.revealAnimationDuration = duration
        return updateSettings(settings)
    }

    @discardableResult
    func saveAllDrafts() -> Bool {
        var candidate = document
        for index in candidate.profiles.indices {
            if var draft = drafts[candidate.profiles[index].id] {
                draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                candidate.profiles[index] = draft
            }
        }
        guard commit(candidate) else { return false }
        drafts.removeAll()
        persistDrafts()
        return true
    }

    private func persistDrafts() {
        guard !storageIsReadOnly else { return }
        do {
            if !hasPersistedDocument {
                try persistence?.save(document)
                hasPersistedDocument = true
            }
            try persistence?.saveDrafts(Array(drafts.values))
            draftRecoveryFailed = false
        } catch {
            draftRecoveryFailed = true
            errorMessage = "下書きの復元用データを保存できませんでした。終了前に変更を保存してください。\n\(error.localizedDescription)"
        }
    }

    private func restoreDrafts() throws {
        let recovered = try persistence?.loadDrafts() ?? []
        for draft in recovered where document.profiles.contains(where: { $0.id == draft.id }) {
            if document.profiles.first(where: { $0.id == draft.id }) != draft { drafts[draft.id] = draft }
        }
        if !drafts.isEmpty { status = "前回の未保存の編集内容を復元しました" }
    }

    func retryLoad() {
        do {
            guard let loaded = try persistence?.load() else { throw DockDataError.invalidData("The configuration file is missing.") }
            document = loaded
            isUsingFallbackData = false
            editingProfileID = loaded.activeProfileID
            drafts.removeAll()
            try restoreDrafts()
            storageIsReadOnly = false
            hasPersistedDocument = true
            errorMessage = nil
            status = "設定を読み込み直しました"
        } catch {
            storageIsReadOnly = true
            errorMessage = "設定を読み込み直せませんでした。\n\(error.localizedDescription)"
        }
    }

    func revealConfiguration() {
        if let persistence { NSWorkspace.shared.activateFileViewerSelecting([persistence.fileURL]) }
    }

    func addItem(_ item: DockItem) {
        var profile = editorProfile
        profile.items.append(item)
        editorProfile = profile
    }

    func moveItem(_ id: UUID, by offset: Int) {
        var profile = editorProfile
        guard let index = profile.items.firstIndex(where: { $0.id == id }),
              profile.items.indices.contains(index + offset) else { return }
        profile.items.swapAt(index, index + offset)
        editorProfile = profile
    }

    func removeItem(_ id: UUID) {
        var profile = editorProfile
        guard let index = profile.items.firstIndex(where: { $0.id == id }) else { return }
        removedItem = (profile.id, profile.items.remove(at: index), index)
        editorProfile = profile
    }

    func isPinned(_ item: DockItem) -> Bool {
        activeProfile.items.contains { $0.id == item.id }
    }

    func removeFromActiveProfile(_ item: DockItem) {
        removeSavedItem(item.id, fromProfile: document.activeProfileID)
    }

    @discardableResult
    func removeSavedItem(_ id: UUID, fromProfile profileID: UUID) -> Bool {
        var candidate = document
        guard let profileIndex = candidate.profiles.firstIndex(where: { $0.id == profileID }),
              let itemIndex = candidate.profiles[profileIndex].items.firstIndex(where: { $0.id == id }) else { return false }
        let removed = candidate.profiles[profileIndex].items.remove(at: itemIndex)
        guard commit(candidate) else { return false }
        if removedItem?.item.id == id { removedItem = nil }
        if var draft = drafts[profileID] {
            draft.items.removeAll { $0.id == id }
            drafts[profileID] = draft == document.profiles[profileIndex] ? nil : draft
            persistDrafts()
        }
        status = "\(removed.name) を Dock から取り外しました"
        return true
    }

    func undoRemoval() {
        guard let removedItem, removedItem.profileID == editingProfileID else { return }
        var profile = editorProfile
        profile.items.insert(removedItem.item, at: min(removedItem.index, profile.items.count))
        editorProfile = profile
        self.removedItem = nil
    }

    func chooseItems(kind: DockItemKind) {
        let panel = NSOpenPanel()
        panel.title = "\(kind.title)を追加"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = kind == .folder
        panel.canChooseFiles = kind != .folder
        if kind == .application { panel.allowedContentTypes = [.applicationBundle] }
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            addItem(DockItem(name: kind == .application ? url.deletingPathExtension().lastPathComponent : url.lastPathComponent,
                             kind: kind, target: url.absoluteString))
        }
    }

    func importCurrentDock() async {
        guard !isReadingNativeDock, !storageIsReadOnly else { return }
        isReadingNativeDock = true
        defer { isReadingNativeDock = false }
        do {
            let items = try await NativeDockReader().readItems()
            let profile = DockProfile(name: uniqueName("Apple Dock から取り込み"), items: items)
            var candidate = document
            candidate.profiles.append(profile)
            if commit(candidate) {
                editingProfileID = profile.id
                status = "Apple Dock の配置を読み取りました"
            }
        } catch { errorMessage = "Apple Dock の配置を読み込めませんでした。\n\(error.localizedDescription)" }
    }

    func openItem(_ item: DockItem) {
        guard !isPreview else { status = "\(item.name) を選択しました"; return }
        let url: URL
        do { url = try ItemLaunchPolicy().validate(item) }
        catch { errorMessage = "項目を開けませんでした。\n\(error.localizedDescription)"; return }
        if item.requiresLaunchConfirmation == true {
            let alert = NSAlert()
            alert.messageText = "読み込んだ項目を開きますか？"
            alert.informativeText = "表示名: \(item.name)\n実際の対象: \(url.isFileURL ? url.path : url.absoluteString)\n信頼できる対象であることを確認してください。"
            alert.addButton(withTitle: "開く")
            alert.addButton(withTitle: "キャンセル")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        if item.kind == .application {
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { [weak self] _, error in
                if let error {
                    Task { @MainActor in self?.errorMessage = "アプリを開けませんでした。\n\(error.localizedDescription)" }
                }
            }
        } else if !NSWorkspace.shared.open(url) {
            errorMessage = "\(item.name) を開けませんでした。"
        }
    }

    func exportProfiles() {
        guard !storageIsReadOnly else { errorMessage = DockDataError.readOnly.localizedDescription; return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "DockStudio-profiles.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try archiveData().write(to: url, options: .atomic)
            status = "プロファイルを書き出しました"
        } catch { errorMessage = "書き出しに失敗しました。\n\(error.localizedDescription)" }
    }

    func importProfiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try stageImport(Data(contentsOf: url))
        } catch { errorMessage = "読み込みに失敗しました。\n\(error.localizedDescription)" }
    }

    func archiveData() throws -> Data {
        guard !storageIsReadOnly else { throw DockDataError.readOnly }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(ProfileArchive(document: document))
    }

    func stageImport(_ data: Data) throws {
        guard !storageIsReadOnly else { throw DockDataError.readOnly }
        pendingImport = PendingProfileImport(document: try ProfileArchive.decode(data))
    }

    func confirmImport(restoreSettings: Bool) {
        guard let pendingImport else { return }
        if mergeProfiles(pendingImport.document.profiles,
                         settings: restoreSettings ? pendingImport.document.settings : nil,
                         activeSourceID: restoreSettings ? pendingImport.document.activeProfileID : nil) {
            self.pendingImport = nil
        }
    }

    @discardableResult
    func mergeProfiles(_ profiles: [DockProfile], settings: DockSettings? = nil, activeSourceID: UUID? = nil) -> Bool {
        var candidate = document
        for source in profiles {
            var copy = source
            copy.id = UUID()
            copy.name = uniqueName(source.name, in: candidate.profiles)
            copy.items = source.items.map { item in
                var copy = item
                copy.id = UUID()
                copy.requiresLaunchConfirmation = true
                return copy
            }
            if source.id == activeSourceID { candidate.activeProfileID = copy.id }
            candidate.profiles.append(copy)
        }
        if let settings { candidate.settings = settings }
        if commit(candidate) {
            if candidate.settings.mode == .native { isDockVisible = false }
            status = "\(profiles.count) 個のプロファイルを追加しました"
            return true
        }
        return false
    }

    private func uniqueName(_ base: String, in profiles: [DockProfile]? = nil) -> String {
        let names = Set((profiles ?? document.profiles).map(\.name))
        if !names.contains(base) { return base }
        var suffix = 2
        while names.contains("\(base) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    private static func initialDocument() -> DockDocument {
        func app(_ id: String, _ name: String) -> DockItem? {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
            return DockItem(name: name, kind: .application, target: url.absoluteString)
        }
        let work = DockProfile(name: "仕事", items: [
            app("com.apple.finder", "Finder"), app("com.apple.Safari", "Safari"),
            app("com.apple.mail", "メール"), app("com.apple.Terminal", "ターミナル"),
            DockItem(name: "スペーサー", kind: .spacer)
        ].compactMap { $0 })
        let personal = DockProfile(name: "プライベート", items: [
            app("com.apple.finder", "Finder"), app("com.apple.Music", "ミュージック"),
            app("com.apple.Photos", "写真")
        ].compactMap { $0 })
        return DockDocument(profiles: [work, personal], activeProfileID: work.id)
    }
}

struct FocusSession {
    var remaining: TimeInterval = 25 * 60
    var deadline: Date?

    func seconds(at date: Date) -> Int {
        max(0, Int(ceil(deadline?.timeIntervalSince(date) ?? remaining)))
    }

    mutating func toggle(at date: Date = .now) {
        if deadline != nil, seconds(at: date) == 0 {
            remaining = 25 * 60
            deadline = date.addingTimeInterval(remaining)
            return
        }
        if deadline != nil {
            remaining = TimeInterval(seconds(at: date))
            deadline = nil
        } else {
            if remaining <= 0 { remaining = 25 * 60 }
            deadline = date.addingTimeInterval(remaining)
        }
    }
}
