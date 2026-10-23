import CoreGraphics
import Foundation

struct DockBarSnapshot: Equatable {
    struct Item: Equatable, Identifiable {
        let id: UUID
        let kind: DockItemKind
        let title: String
        let iconKey: String
        let dividerBefore: Bool
        let isRunning: Bool
        let badge: String?
        let availability: ItemAvailability
        let isBouncing: Bool
        let isAttentionRequested: Bool
    }

    struct Trash: Equatable {
        let state: TrashState
        let dividerBefore: Bool
    }

    let items: [Item]
    let trash: Trash
    let position: DockPosition
    let appearance: DockAppearance
    let iconSize: Double
    let maximumIconSize: Double
    let magnificationEnabled: Bool
    let reduceMotion: Bool
}

@MainActor
enum DockBarSnapshotBuilder {
    static func make(store: DockStore, availableLength: CGFloat? = nil, magnificationEnabled: Bool? = nil,
                     forceFit: Bool = false, systemReduceMotion: Bool = false) -> DockBarSnapshot {
        let layout = store.displayedLayout
        let appearance = store.appearance
        let settings = store.document.settings
        let reduceMotion = appearance.reduceMotion || systemReduceMotion
        let identities = layout.items.map(\.applicationIdentity)
        let runningIdentities = Set(store.runningItems.compactMap(\.applicationIdentity))
        let items = layout.items.enumerated().map { index, item in
            let identity = identities[index]
            return DockBarSnapshot.Item(
                id: item.id, kind: item.kind, title: item.name,
                iconKey: "\(item.kind.rawValue):\(item.target ?? item.bundleIdentifier ?? "")",
                dividerBefore: layout.dividerBefore.contains(index),
                isRunning: appearance.runningIndicators && identity.map(runningIdentities.contains) == true,
                badge: NotificationBadgeSnapshot.badge(for: item, in: store.notificationBadges),
                availability: store.itemAvailability.status(of: item),
                isBouncing: settings.launchBounce && store.launchingItemIDs.contains(item.id) && !reduceMotion,
                isAttentionRequested: settings.attentionBounce
                    && identity.map(store.attentionRequestingIdentities.contains) == true)
        }
        return DockBarSnapshot(
            items: items,
            trash: .init(state: store.trashState, dividerBefore: layout.dividerBefore.contains(items.count)),
            position: settings.position, appearance: appearance,
            iconSize: DockMetrics.effectiveIconSize(for: store, availableLength: availableLength,
                                                    magnificationEnabled: magnificationEnabled, forceFit: forceFit),
            maximumIconSize: store.effectiveIconSize,
            magnificationEnabled: magnificationEnabled ?? appearance.magnification,
            reduceMotion: reduceMotion)
    }
}
