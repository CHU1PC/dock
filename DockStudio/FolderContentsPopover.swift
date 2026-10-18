import SwiftUI

struct FolderContentsPopover: View {
    let folder: DockItem
    let dockPosition: DockPosition
    let reduceMotion: Bool
    let openItem: (DockItem) -> Void
    let openInFinder: (DockItem) -> Void
    let updateDisplayStyle: (DockItem, FolderContentsDisplayStyle) -> Bool
    let onSortOrderChange: (FolderSortOrder) -> Void

    @State private var result: Result<[DockItem], Error>?
    @State private var sortOrder: FolderSortOrder = .name
    @State private var displayStyle: FolderContentsDisplayStyle

    init(folder: DockItem, dockPosition: DockPosition, reduceMotion: Bool,
         openItem: @escaping (DockItem) -> Void, openInFinder: @escaping (DockItem) -> Void,
         updateDisplayStyle: @escaping (DockItem, FolderContentsDisplayStyle) -> Bool,
         onSortOrderChange: @escaping (FolderSortOrder) -> Void) {
        self.folder = folder
        self.dockPosition = dockPosition
        self.reduceMotion = reduceMotion
        self.openItem = openItem
        self.openInFinder = openInFinder
        self.updateDisplayStyle = updateDisplayStyle
        self.onSortOrderChange = onSortOrderChange
        _sortOrder = State(initialValue: folder.folderSortOrder ?? .name)
        _displayStyle = State(initialValue: folder.folderContentsDisplayStyle ?? .list)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(folder.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Picker("並べ替え", selection: $sortOrder) {
                    ForEach(FolderSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .onChange(of: sortOrder) { _, order in onSortOrderChange(order) }
                Menu {
                    ForEach(FolderContentsDisplayStyle.allCases) { style in
                        Button {
                            if updateDisplayStyle(folder, style) { displayStyle = style }
                        } label: {
                            if displayStyle == style {
                                Label(style.title, systemImage: "checkmark")
                            } else {
                                Text(style.title)
                            }
                        }
                        .disabled(style == .fan && dockPosition != .bottom)
                    }
                } label: {
                    Label("表示形式: \(displayStyle.title)", systemImage: "chevron.down")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(dockPosition == .bottom ? "フォルダの表示形式" : "Fan は下に配置した Dock で選べます")
            }

            Group {
                if let result {
                    switch result {
                    case .success(let items) where items.isEmpty:
                        ContentUnavailableView("フォルダは空です", systemImage: "folder")
                            .frame(minHeight: 100)
                    case .success(let items):
                        contents(items)
                    case .failure(let error):
                        ContentUnavailableView(
                            "フォルダを読み込めません",
                            systemImage: "folder.badge.questionmark",
                            description: Text(error.localizedDescription)
                        )
                        .frame(minHeight: 100)
                    }
                } else {
                    ProgressView("読み込み中")
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
            }

            Divider()

            Button {
                openInFinder(folder)
            } label: {
                Label("Finder で開く", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 280)
        .transaction { if reduceMotion { $0.animation = nil } }
        .task(id: "\(folder.target ?? "")-\(sortOrder.rawValue)") {
            guard let url = folder.targetURL, url.isFileURL else {
                result = .failure(FolderContentsError.invalidFolder)
                return
            }
            let currentSortOrder = sortOrder
            result = await Task.detached(priority: .userInitiated) {
                Result { try FolderContentsReader.read(at: url, sortOrder: currentSortOrder) }
            }.value
        }
    }

    @ViewBuilder
    private func contents(_ items: [DockItem]) -> some View {
        let canFan = displayStyle == .fan && dockPosition == .bottom
            && items.count <= FolderFanLayout.maximumItemCount
        if canFan {
            fan(items)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if displayStyle == .fan {
                    Text(fallbackMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                list(items)
            }
        }
    }

    private var fallbackMessage: String {
        if dockPosition != .bottom {
            return "Fan は下に配置した Dock で使えないため、一覧で表示します。"
        }
        return "Fan に収まる項目数を超えたため、一覧で表示します。"
    }

    private func list(_ items: [DockItem]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(items) { item in
                    Button {
                        openItem(item)
                    } label: {
                        Label(item.name, systemImage: item.kind.symbol)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .help(item.targetURL?.path ?? item.name)
                    .accessibilityLabel(item.name)
                }
            }
        }
        .frame(maxHeight: 320)
    }

    private func fan(_ items: [DockItem]) -> some View {
        GeometryReader { geometry in
            let positions = FolderFanLayout.positions(count: items.count, width: geometry.size.width,
                                                      height: geometry.size.height)
            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        openItem(item)
                    } label: {
                        ItemIcon(item: item, size: 34)
                    }
                    .buttonStyle(.plain)
                    .help(item.name)
                    .accessibilityLabel(item.name)
                    .position(positions[index])
                }
            }
        }
        .frame(height: 180)
    }
}

private enum FolderContentsError: LocalizedError {
    case invalidFolder

    var errorDescription: String? {
        "フォルダの参照先が正しくありません。"
    }
}
