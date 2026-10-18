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
            Image(nsImage: DockIconRenderer.image(url: url, style: style, scheme: colorScheme))
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
    let folder: DockItem
    let openItem: (DockItem) -> Void
    let openInFinder: (DockItem) -> Void

    @State private var result: Result<[DockItem], Error>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(folder.name)
                .font(.headline)
                .lineLimit(1)

            Group {
                if let result {
                    switch result {
                    case .success(let items) where items.isEmpty:
                        ContentUnavailableView("フォルダは空です", systemImage: "folder")
                            .frame(minHeight: 100)
                    case .success(let items):
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
        .task(id: folder.target) {
            guard let url = folder.targetURL, url.isFileURL else {
                result = .failure(FolderContentsError.invalidFolder)
                return
            }
            result = await Task.detached(priority: .userInitiated) {
                Result { try FolderContentsReader.read(at: url) }
            }.value
        }
    }
}

private enum FolderContentsError: LocalizedError {
    case invalidFolder

    var errorDescription: String? {
        "フォルダの参照先が正しくありません。"
    }
}
