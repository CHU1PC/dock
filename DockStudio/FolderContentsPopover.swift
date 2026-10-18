import SwiftUI

struct FolderStackIcon: View {
    let folder: DockItem
    let size: Double
    let style: DockAppearance.IconStyle

    @State private var contents: [DockItem]?
    @State private var failedToRead = false
    @Environment(\.colorScheme) private var colorScheme

    private var plainFolder: DockItem {
        var item = folder
        item.folderDisplayStyle = .folder
        return item
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ItemIcon(item: plainFolder, size: size, style: style, appliesGlassEffect: false)

            if case .preview(let items) = FolderStackIconModel.state(contents: contents, failedToRead: failedToRead) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    childIcon(item)
                        .frame(width: size * 0.43, height: size * 0.43)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: size * 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.07))
                        .overlay(RoundedRectangle(cornerRadius: size * 0.07).strokeBorder(.white.opacity(0.45), lineWidth: 0.6))
                        .rotationEffect(.degrees(Double(index - 1) * 7))
                        .offset(x: CGFloat(index - 1) * size * 0.15,
                                y: -size * (0.08 + Double(index % 2) * 0.16))
                        .zIndex(Double(index))
                }
            }

            if case .failed = FolderStackIconModel.state(contents: contents, failedToRead: failedToRead) {
                Image(systemName: "exclamationmark")
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .background(.orange, in: Circle())
                    .offset(x: size * 0.03, y: size * 0.02)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: folder.target) { await reloadContents() }
        .onHover { if $0 { Task { await reloadContents() } } }
    }

    @ViewBuilder
    private func childIcon(_ item: DockItem) -> some View {
        if let url = item.targetURL, url.isFileURL {
            Image(nsImage: DockIconRenderer.image(url: url, style: style, pointSize: size * 0.43, scheme: colorScheme))
                .resizable().interpolation(.high).scaledToFit()
        } else {
            Image(systemName: item.kind.symbol)
                .resizable().scaledToFit()
                .foregroundStyle(style == .original ? StudioColor.accent : .primary)
                .padding(size * 0.04)
        }
    }

    @MainActor
    private func reloadContents() async {
        guard let url = folder.targetURL, url.isFileURL else {
            contents = nil
            failedToRead = true
            return
        }
        let result = await Task.detached(priority: .utility) {
            Result { try FolderContentsReader.read(at: url) }
        }.value
        switch result {
        case .success(let items):
            contents = items
            failedToRead = false
        case .failure:
            contents = nil
            failedToRead = true
        }
    }
}

struct FolderContentsPopover: View {
    @Environment(\.dismiss) private var dismiss
    let folder: DockItem
    @Binding var displayMode: FolderDisplayMode
    let onDisplayModeChange: (FolderDisplayMode) -> Void
    let dockPosition: DockPosition
    let reduceMotion: Bool
    let openItem: (DockItem) -> Void
    let openInFinder: (DockItem) -> Void
    let moveDroppedItemsIntoFolder: ([URL], URL?) -> Void
    let updateDisplayStyle: (DockItem, FolderContentsDisplayStyle) -> Bool
    let onSortOrderChange: (FolderSortOrder) -> Void

    @State private var result: Result<[DockItem], Error>?
    @State private var sortOrder: FolderSortOrder = .name
    @State private var displayStyle: FolderContentsDisplayStyle
    @FocusState private var focusedGridItemID: UUID?

    init(folder: DockItem, displayMode: Binding<FolderDisplayMode>,
         onDisplayModeChange: @escaping (FolderDisplayMode) -> Void,
         dockPosition: DockPosition, reduceMotion: Bool,
         openItem: @escaping (DockItem) -> Void, openInFinder: @escaping (DockItem) -> Void,
         moveDroppedItemsIntoFolder: @escaping ([URL], URL?) -> Void,
         updateDisplayStyle: @escaping (DockItem, FolderContentsDisplayStyle) -> Bool,
         onSortOrderChange: @escaping (FolderSortOrder) -> Void) {
        self.folder = folder
        _displayMode = displayMode
        self.onDisplayModeChange = onDisplayModeChange
        self.dockPosition = dockPosition
        self.reduceMotion = reduceMotion
        self.openItem = openItem
        self.openInFinder = openInFinder
        self.moveDroppedItemsIntoFolder = moveDroppedItemsIntoFolder
        self.updateDisplayStyle = updateDisplayStyle
        self.onSortOrderChange = onSortOrderChange
        _sortOrder = State(initialValue: folder.folderSortOrder ?? .name)
        _displayStyle = State(initialValue: folder.effectiveFolderContentsDisplayStyle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(folder.name)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                            setDisplayStyle(style)
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
        .frame(width: 320)
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .transaction { if reduceMotion { $0.animation = nil } }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: { providers in
            guard !providers.isEmpty else { return false }
            Task { @MainActor in
                var urls: [URL] = []
                for provider in providers {
                    let url: URL? = await withCheckedContinuation { continuation in
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
                    }
                    if let url, url.isFileURL { urls.append(url) }
                }
                moveDroppedItemsIntoFolder(urls, folder.targetURL)
            }
            return true
        })
        .task(id: "\(folder.target ?? "")-\(sortOrder.rawValue)") {
            guard let url = folder.targetURL, url.isFileURL else {
                result = .failure(FolderContentsError.invalidFolder)
                return
            }
            let currentSortOrder = sortOrder
            let loaded = await Task.detached(priority: .userInitiated) {
                Result { try FolderContentsReader.read(at: url, sortOrder: currentSortOrder) }
            }.value
            result = loaded
            if case .success(let items) = loaded {
                updateResolvedDisplayMode(for: items)
                if displayMode == .grid { focusedGridItemID = items.first?.id }
            }
        }
    }

    @ViewBuilder
    private func contents(_ items: [DockItem]) -> some View {
        let style = resolvedStyle(itemCount: items.count)
        if style == .grid {
            grid(items)
        } else if style == .fan && dockPosition == .bottom
                    && items.count <= FolderFanLayout.maximumItemCount {
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
                    Button { openItem(item) } label: {
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

    private func grid(_ items: [DockItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(minimum: 100)), GridItem(.flexible(minimum: 100))],
                          alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        gridButton(for: item)
                    }
                }
            }
            .onChange(of: focusedGridItemID) {
                if let focusedGridItemID { proxy.scrollTo(focusedGridItemID, anchor: .center) }
            }
            .frame(maxHeight: 320)
        }
    }

    private func fan(_ items: [DockItem]) -> some View {
        GeometryReader { geometry in
            let positions = FolderFanLayout.positions(count: items.count, width: geometry.size.width,
                                                      height: geometry.size.height)
            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button { openItem(item) } label: {
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

    private func gridButton(for item: DockItem) -> some View {
        Button { openItem(item) } label: {
            VStack(spacing: 5) {
                ItemIcon(item: item, size: 34)
                Text(item.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.targetURL?.path ?? item.name)
        .accessibilityLabel(item.name)
        .id(item.id)
        .focused($focusedGridItemID, equals: item.id)
        .onKeyPress(phases: [.down]) { press in
            guard let key = DockKeyboardNavigation.Key(press), case .arrow(let direction) = key else {
                return .ignored
            }
            return moveGridFocus(direction)
        }
    }

    private func moveGridFocus(_ direction: DockKeyboardNavigation.Arrow) -> KeyPress.Result {
        guard case .success(let items) = result, !items.isEmpty,
              let current = items.firstIndex(where: { $0.id == focusedGridItemID }) else { return .ignored }
        let offset: Int
        switch direction {
        case .left: offset = -1
        case .right: offset = 1
        case .up: offset = -2
        case .down: offset = 2
        }
        let target = current + offset
        guard items.indices.contains(target) else { return .ignored }
        focusedGridItemID = items[target].id
        return .handled
    }

    private func setDisplayStyle(_ style: FolderContentsDisplayStyle) {
        guard updateDisplayStyle(folder, style) else { return }
        displayStyle = style
        if case .success(let items) = result {
            updateResolvedDisplayMode(for: items)
            if displayMode == .grid { focusedGridItemID = items.first?.id }
        } else {
            updateDisplayMode(.list)
        }
    }

    private func resolvedStyle(itemCount: Int) -> FolderContentsDisplayStyle {
        guard displayStyle == .automatic else { return displayStyle }
        return FolderContentsAutomaticStyle.resolve(itemCount: itemCount, position: dockPosition)
    }

    private func updateResolvedDisplayMode(for items: [DockItem]) {
        updateDisplayMode(resolvedStyle(itemCount: items.count) == .grid ? .grid : .list)
    }

    private func updateDisplayMode(_ mode: FolderDisplayMode) {
        guard displayMode != mode else { return }
        displayMode = mode
        onDisplayModeChange(mode)
    }
}

private enum FolderContentsError: LocalizedError {
    case invalidFolder

    var errorDescription: String? {
        "フォルダの参照先が正しくありません。"
    }
}
