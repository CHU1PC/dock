import SwiftUI

struct FolderContentsPopover: View {
    @Environment(\.dismiss) private var dismiss
    let folder: DockItem
    @Binding var displayMode: FolderDisplayMode
    let onDisplayModeChange: (FolderDisplayMode) -> Void
    let openItem: (DockItem) -> Void
    let openInFinder: (DockItem) -> Void

    @State private var result: Result<[DockItem], Error>?
    @FocusState private var focusedGridItemID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(folder.name)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("表示形式", selection: $displayMode) {
                    ForEach(FolderDisplayMode.allCases) { mode in
                        Image(systemName: mode.symbol)
                            .accessibilityLabel(mode.title)
                            .tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
                .accessibilityLabel("表示形式")
                .onChange(of: displayMode) {
                    onDisplayModeChange(displayMode)
                    if displayMode == .grid, case .success(let items) = result {
                        focusedGridItemID = items.first?.id
                    }
                }
            }

            Group {
                if let result {
                    switch result {
                    case .success(let items) where items.isEmpty:
                        ContentUnavailableView("フォルダは空です", systemImage: "folder")
                            .frame(minHeight: 100)
                    case .success(let items):
                        ScrollViewReader { proxy in
                            ScrollView {
                                switch displayMode {
                                case .list:
                                    LazyVStack(alignment: .leading, spacing: 2) {
                                        ForEach(items) { item in
                                            listButton(for: item)
                                        }
                                    }
                                case .grid:
                                    LazyVGrid(columns: [GridItem(.flexible(minimum: 100)), GridItem(.flexible(minimum: 100))],
                                              alignment: .leading, spacing: 8) {
                                        ForEach(items) { item in
                                            gridButton(for: item)
                                        }
                                    }
                                }
                            }
                            .onChange(of: focusedGridItemID) {
                                if let focusedGridItemID { proxy.scrollTo(focusedGridItemID, anchor: .center) }
                            }
                            .frame(maxHeight: 320)
                        }
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
        .task(id: folder.target) {
            guard let url = folder.targetURL, url.isFileURL else {
                result = .failure(FolderContentsError.invalidFolder)
                return
            }
            let loaded = await Task.detached(priority: .userInitiated) {
                Result { try FolderContentsReader.read(at: url) }
            }.value
            result = loaded
            if displayMode == .grid, case .success(let items) = loaded {
                focusedGridItemID = items.first?.id
            }
        }
    }

    private func listButton(for item: DockItem) -> some View {
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
}

private enum FolderContentsError: LocalizedError {
    case invalidFolder

    var errorDescription: String? {
        "フォルダの参照先が正しくありません。"
    }
}
