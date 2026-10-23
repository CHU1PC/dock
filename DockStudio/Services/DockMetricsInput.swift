import Foundation

/// `DockMetrics` が `DockStore` から読む値だけをまとめた値型。
struct DockMetricsInput: Equatable {
    var kinds: [DockItemKind]
    var dividerBefore: Set<Int>
    var position: DockPosition
    var effectiveIconSize: Double
    var background: DockAppearance.Background
    var magnification: Bool
    var magnificationScale: Double
    var minimizedSlots: Int

    @MainActor
    init(store: DockStore) {
        let layout = store.displayedLayout
        kinds = layout.items.map(\.kind)
        dividerBefore = layout.dividerBefore
        position = store.document.settings.position
        effectiveIconSize = store.effectiveIconSize
        background = store.appearance.background
        magnification = store.appearance.magnification
        magnificationScale = store.appearance.magnificationScale
        minimizedSlots = store.minimizedWindowController.state.reservedSlots
    }

    init(kinds: [DockItemKind], dividerBefore: Set<Int> = [], position: DockPosition = .bottom,
         effectiveIconSize: Double, background: DockAppearance.Background = .system,
         magnification: Bool = true, magnificationScale: Double = 1.45, minimizedSlots: Int = 0) {
        self.kinds = kinds
        self.dividerBefore = dividerBefore
        self.position = position
        self.effectiveIconSize = effectiveIconSize
        self.background = background
        self.magnification = magnification
        self.magnificationScale = magnificationScale
        self.minimizedSlots = minimizedSlots
    }
}
