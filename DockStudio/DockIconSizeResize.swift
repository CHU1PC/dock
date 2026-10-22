import SwiftUI

enum DockIconSizeResize {
    static func size(initialSize: Double, dragTranslation: CGSize, position: DockPosition) -> Double {
        let inwardDistance: Double
        switch position {
        case .bottom:
            inwardDistance = -Double(dragTranslation.height)
        case .left:
            inwardDistance = Double(dragTranslation.width)
        case .right:
            inwardDistance = -Double(dragTranslation.width)
        }
        guard inwardDistance.isFinite else { return initialSize }
        return min(DockSettings.iconSizeRange.upperBound,
                   max(DockSettings.iconSizeRange.lowerBound, initialSize + inwardDistance))
    }
}

struct DockIconSizeResizeHandle: View {
    @Environment(DockStore.self) private var store
    @State private var initialSize: Double?
    let vertical: Bool
    let iconSize: Double

    private var lineSize: CGSize { DockDividerLine.size(iconSize: iconSize, vertical: vertical) }
    private var resizeCursor: NSCursor { vertical ? .resizeLeftRight : .resizeUpDown }

    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: vertical ? max(54, lineSize.width) : 20, height: vertical ? 20 : max(54, lineSize.height))
            .overlay {
                Rectangle()
                    .fill(.primary.opacity(0.55))
                    .frame(width: lineSize.width, height: lineSize.height)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 3)
                .onChanged { value in
                    if initialSize == nil { initialSize = store.effectiveIconSize }
                    guard let initialSize else { return }
                    store.stageIconSize(DockIconSizeResize.size(
                        initialSize: initialSize,
                        dragTranslation: value.translation,
                        position: store.document.settings.position
                    ))
                }
                .onEnded { _ in
                    _ = store.finishIconSizeEditing()
                    initialSize = nil
                })
            .onHover { hovering in
                if hovering { resizeCursor.push() } else { resizeCursor.pop() }
            }
            .accessibilityLabel("Dock のアイコンサイズ")
            .accessibilityHint("区切り線をドラッグしてサイズを変更")
    }
}
