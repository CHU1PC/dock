import SwiftUI

enum DockDragOutRemoval {
    static let space = "dockBarDragOut"
    static let minimumDistance: CGFloat = 6
    static let margin: CGFloat = 12

    static func isOutside(location: CGPoint, barSize: CGSize, margin: CGFloat = margin) -> Bool {
        guard barSize.width > 0, barSize.height > 0 else { return false }
        return !CGRect(origin: .zero, size: barSize).insetBy(dx: -margin, dy: -margin).contains(location)
    }
}

struct DragOutToRemove: ViewModifier {
    let enabled: Bool
    let barSize: CGSize
    let onRemove: () -> Void
    @State private var translation: CGSize = .zero
    @State private var outside = false
    @GestureState private var tracking = false

    func body(content: Content) -> some View {
        content
            .opacity(outside ? 0.45 : 1)
            .overlay(alignment: .top) {
                if outside {
                    Text("取り外す").font(.caption.weight(.medium)).lineLimit(1)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                        .fixedSize().offset(y: -26)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .offset(translation)
            .zIndex(translation == .zero ? 0 : 1)
            .highPriorityGesture(enabled ? drag : nil)
            .onChange(of: tracking) { if !tracking { reset() } }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: DockDragOutRemoval.minimumDistance, coordinateSpace: .named(DockDragOutRemoval.space))
            .updating($tracking) { _, state, _ in state = true }
            .onChanged { value in
                translation = value.translation
                outside = DockDragOutRemoval.isOutside(location: value.location, barSize: barSize)
            }
            .onEnded { value in
                let remove = DockDragOutRemoval.isOutside(location: value.location, barSize: barSize)
                reset()
                if remove { onRemove() }
            }
    }

    private func reset() {
        translation = .zero
        outside = false
    }
}
