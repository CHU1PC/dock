import Foundation

/// 同じ項目の重複追加を避ける規則。標準 Dock の挙動は未確認で、対象の種類はここだけで変える。
enum DuplicateItemPolicy {
    static let deduplicatedKinds: Set<DockItemKind> = [.application]

    static func key(for item: DockItem) -> String? {
        guard deduplicatedKinds.contains(item.kind) else { return nil }
        if item.kind == .application { return item.applicationIdentity }
        guard let url = item.targetURL, url.isFileURL else { return nil }
        return "path:\(url.standardizedFileURL.resolvingSymlinksInPath().path)"
    }

    /// 既存の項目と、同じ呼び出しの中で先に現れた項目と重なるものを、追加する側と避ける側に分ける。
    static func split(_ candidates: [DockItem], existing: [DockItem]) -> (accepted: [DockItem], duplicates: [DockItem]) {
        var seen = Set(existing.compactMap(key(for:)))
        var accepted: [DockItem] = []
        var duplicates: [DockItem] = []
        for item in candidates {
            if let key = key(for: item), !seen.insert(key).inserted { duplicates.append(item) } else { accepted.append(item) }
        }
        return (accepted, duplicates)
    }

    static func message(for duplicates: [DockItem]) -> String {
        "\(duplicates.map(\.name).joined(separator: "、")) は既に Dock にあるため、追加しませんでした"
    }
}
