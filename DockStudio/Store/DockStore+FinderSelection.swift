import AppKit

extension DockStore {
    @discardableResult
    func addFinderSelection(_ urls: [URL]) -> FinderSelectionAddition {
        let candidates = urls.map { url in
            FinderSelectionCandidate.resolve(url) { item in
            do {
                _ = try ItemLaunchPolicy().validate(item)
                return nil
            } catch {
                return error.localizedDescription
            }
        }
        }
        let addition = FinderSelectionAddition.prepare(candidates)
        guard !storageIsReadOnly else {
            errorMessage = DockDataError.readOnly.localizedDescription
            return FinderSelectionAddition(items: [], rejected: addition.rejected)
        }
        guard let profileIndex = document.profiles.firstIndex(where: { $0.id == document.activeProfileID }) else {
            errorMessage = "追加先のプロファイルが見つかりません。"
            return FinderSelectionAddition(items: [], rejected: addition.rejected)
        }
        let existing = document.profiles[profileIndex].items
        let (items, duplicates) = DuplicateItemPolicy.split(addition.items, existing: existing)
        var candidate = document
        candidate.profiles[profileIndex].items.append(contentsOf: items)
        if !items.isEmpty, !commit(candidate) {
            return FinderSelectionAddition(items: [], rejected: addition.rejected)
        }
        if !items.isEmpty { status = "\(items.count) 個の項目を有効なプロファイル「\(document.profiles[profileIndex].name)」に追加しました" }

        var rejected = addition.rejected
        rejected.append(contentsOf: duplicates.map {
            FinderSelectionRejection(name: $0.name, reason: "すでに追加されています。")
        })
        if !rejected.isEmpty {
            errorMessage = "一部の項目を追加できませんでした。\n" + rejected.map { "\($0.name): \($0.reason)" }.joined(separator: "\n")
        }
        return FinderSelectionAddition(items: items, rejected: rejected)
    }
}
