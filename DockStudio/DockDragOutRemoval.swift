import SwiftUI
import Observation

struct DockDragOutStateMachine {
    enum EndReason: Equatable {
        case dropInside
        case dropOutsideRemoval
        case cancelled
        case externalDrop
    }

    private(set) var isDragging = false
    private(set) var isCancelled = false

    mutating func begin() {
        isDragging = true
        isCancelled = false
    }

    mutating func cancelIfDragging() -> Bool {
        guard isDragging else { return false }
        isCancelled = true
        return true
    }

    mutating func finish(_ reason: EndReason = .dropInside) -> Bool {
        let wasCancelled = isCancelled || reason == .cancelled
        isDragging = false
        isCancelled = false
        return wasCancelled
    }
}

@MainActor
@Observable
final class DockDragOutCancellation {
    static let shared = DockDragOutCancellation()

    private var state = DockDragOutStateMachine()
    var isDragging: Bool { state.isDragging }
    var isCancelled: Bool { state.isCancelled }

    func begin() {
        state.begin()
    }

    func cancelIfDragging() -> Bool {
        state.cancelIfDragging()
    }

    func finish(_ reason: DockDragOutStateMachine.EndReason = .dropInside) -> Bool {
        state.finish(reason)
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
    var isEjectable: () -> Bool = { false }
    var onEject: () -> Void = {}
    var onDragMove: (CGPoint?) -> Void = { _ in }
    var onDragFinish: (CGPoint?, Bool) -> Void = { _, _ in }
    @State private var translation: CGSize = .zero
    @State private var outside = false
    @State private var draggingEjectableVolume = false
    @GestureState private var tracking = false

    func body(content: Content) -> some View {
        let cancellation = DockDragOutCancellation.shared
        content
            .opacity(outside && !cancellation.isCancelled ? 0.45 : 1)
            .offset(translation)
            .overlay(alignment: vertical ? .center : .top) {
                if outside && !cancellation.isCancelled {
                    Group {
                        if draggingEjectableVolume {
                            Label("ディスクを取り出す", systemImage: "eject.fill")
                        } else {
                            Text("取り外す")
                        }
                    }
                    .font(.caption.weight(.medium)).lineLimit(1)
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
            if cancellation.isCancelled { reset(); onDragMove(nil) }
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
                    draggingEjectableVolume = isEjectable()
                }
                translation = value.translation
                outside = DockDragOutRemoval.isOutside(location: value.location, bounds: bounds)
                onDragMove(outside ? nil : value.location)
            }
            .onEnded { value in
                let cancelled = DockDragOutCancellation.shared.finish(
                    DockDragOutRemoval.isOutside(location: value.location, bounds: bounds)
                        ? .dropOutsideRemoval : .dropInside
                )
                let remove = !cancelled && DockDragOutRemoval.isOutside(location: value.location, bounds: bounds)
                let eject = remove && draggingEjectableVolume
                onDragFinish(remove || cancelled ? nil : value.location, cancelled)
                reset()
                if eject { onEject() }
                else if remove { onRemove() }
            }
    }

    private func reset() {
        translation = .zero
        outside = false
        draggingEjectableVolume = false
    }
}
