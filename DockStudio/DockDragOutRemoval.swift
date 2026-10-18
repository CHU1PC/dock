import SwiftUI
import Observation

@MainActor
@Observable
final class DockDragOutCancellation {
    static let shared = DockDragOutCancellation()

    private(set) var isDragging = false
    private(set) var isCancelled = false

    func begin() {
        isDragging = true
        isCancelled = false
    }

    func cancelIfDragging() -> Bool {
        guard isDragging else { return false }
        isCancelled = true
        return true
    }

    func finish() -> Bool {
        let wasCancelled = isCancelled
        isDragging = false
        isCancelled = false
        return wasCancelled
    }
}

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

    static func shouldIgnoreMouseEvents(pointerIsInteractive: Bool, trackingMenus: Bool,
                                        hasActivePopover: Bool, isDragging: Bool) -> Bool {
        !pointerIsInteractive && !trackingMenus && !hasActivePopover && !isDragging
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
        let cancellation = DockDragOutCancellation.shared
        content
            .opacity(outside && !cancellation.isCancelled ? 0.45 : 1)
            .offset(translation)
            .overlay(alignment: vertical ? .center : .top) {
                if outside && !cancellation.isCancelled {
                    Text("取り外す").font(.caption.weight(.medium)).lineLimit(1)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                        .fixedSize().offset(y: vertical ? 0 : -26)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .zIndex(translation == .zero ? 0 : 1)
            .highPriorityGesture(enabled ? drag : nil)
            .onChange(of: tracking) {
                if !tracking {
                    if cancellation.isDragging { _ = cancellation.finish() }
                    reset()
                }
            }
            .onChange(of: cancellation.isCancelled) {
                if cancellation.isCancelled { reset() }
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: DockDragOutRemoval.minimumDistance, coordinateSpace: .named(DockDragOutRemoval.space))
            .updating($tracking) { _, state, _ in state = true }
            .onChanged { value in
                guard !DockDragOutCancellation.shared.isCancelled else {
                    reset()
                    return
                }
                if !DockDragOutCancellation.shared.isDragging {
                    DockDragOutCancellation.shared.begin()
                }
                translation = value.translation
                outside = DockDragOutRemoval.isOutside(location: value.location, bounds: bounds)
            }
            .onEnded { value in
                let cancelled = DockDragOutCancellation.shared.finish()
                let remove = !cancelled && DockDragOutRemoval.isOutside(location: value.location, bounds: bounds)
                reset()
                if remove { onRemove() }
            }
    }

    private func reset() {
        translation = .zero
        outside = false
    }
}
