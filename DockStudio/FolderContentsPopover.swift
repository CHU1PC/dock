import SwiftUI

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
