import Foundation

extension DockStore {
    func restoreRecentAppHistory() {
        guard let url = recentAppHistoryURL else { return }
        do {
            if document.settings.showRecentApps {
                recentAppItems = try RecentAppHistoryPersistence.load(from: url)
            } else {
                try RecentAppHistoryPersistence.clear(url)
            }
        } catch {
            recentAppItems = []
            errorMessage = "最近使ったアプリの履歴を読み込めませんでした。\n\(error.localizedDescription)"
        }
    }

    func recordRecentApp(_ item: DockItem) {
        guard document.settings.showRecentApps,
              let url = recentAppHistoryURL,
              item.kind == .application,
              item.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        let updated = RecentAppHistory.recording(item, in: recentAppItems)
        guard updated != recentAppItems else { return }
        do {
            try RecentAppHistoryPersistence.save(updated, to: url)
            recentAppItems = updated
        } catch {
            errorMessage = "最近使ったアプリの履歴を保存できませんでした。\n\(error.localizedDescription)"
        }
    }

    func clearRecentAppHistory() {
        recentAppItems = []
        guard let url = recentAppHistoryURL else { return }
        do {
            try RecentAppHistoryPersistence.clear(url)
        } catch {
            errorMessage = "最近使ったアプリの履歴を消去できませんでした。\n\(error.localizedDescription)"
        }
    }
}
