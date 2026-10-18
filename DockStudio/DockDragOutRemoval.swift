import SwiftUI

enum DockDragOutRemoval {
    static let space = "dockBarDragOut"
    static let minimumDistance: CGFloat = 6
    static let margin: CGFloat = 12

    /// DockBar 全体の寸法から、見える背景の矩形を求める。ラベル用の透明な領域は含めない。
    static func visibleBounds(barSize: CGSize, vertical: Bool, thickness: CGFloat) -> CGRect {
        guard barSize.width > 0, barSize.height > 0 else { return .zero }
        if vertical {
            let width = min(thickness, barSize.width)
            return CGRect(x: (barSize.width - width) / 2, y: 0, width: width, height: barSize.height)
        }
        let height = min(thickness, barSize.height)
        return CGRect(x: 0, y: barSize.height - height, width: barSize.width, height: height)
    }

    static func isOutside(location: CGPoint, bounds: CGRect, margin: CGFloat = margin) -> Bool {
        guard !bounds.isEmpty else { return false }
        return !bounds.insetBy(dx: -margin, dy: -margin).contains(location)
    }
}

struct DragOutToRemove: ViewModifier {
    let enabled: Bool
    let vertical: Bool
    let bounds: CGRect
    let onRemove: () -> Void
    @State private var translation: CGSize = .zero
    @State private var outside = false
    @GestureState private var tracking = false

    func body(content: Content) -> some View {
        content
            .opacity(outside ? 0.45 : 1)
            .offset(translation)
            .overlay(alignment: vertical ? .center : .top) {
                if outside {
                    Text("取り外す").font(.caption.weight(.medium)).lineLimit(1)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                        .fixedSize().offset(y: vertical ? 0 : -26)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .zIndex(translation == .zero ? 0 : 1)
            .highPriorityGesture(enabled ? drag : nil)
            .onChange(of: tracking) { if !tracking { reset() } }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: DockDragOutRemoval.minimumDistance, coordinateSpace: .named(DockDragOutRemoval.space))
            .updating($tracking) { _, state, _ in state = true }
            .onChanged { value in
                translation = value.translation
                outside = DockDragOutRemoval.isOutside(location: value.location, bounds: bounds)
            }
            .onEnded { value in
                let remove = DockDragOutRemoval.isOutside(location: value.location, bounds: bounds)
                reset()
                if remove { onRemove() }
            }
    }

    private func reset() {
        translation = .zero
        outside = false
    }
}
