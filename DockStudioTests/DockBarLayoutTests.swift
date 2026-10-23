import XCTest
@testable import DockStudio

@MainActor
final class DockBarLayoutTests: XCTestCase {
    private func makeStore(kinds: [DockItemKind], arrangement: DockArrangement = .free, size: Double = 52,
                           magnification: Bool = true, background: DockAppearance.Background = .system) -> DockStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DockStore(persistence: ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json")))
        for (index, kind) in kinds.enumerated() {
            store.addItem(DockItem(name: "item\(index)", kind: kind, target: nil, bundleIdentifier: "com.example.\(index)"))
        }
        var settings = store.document.settings
        settings.arrangement = arrangement
        settings.iconSize = size
        settings.position = .bottom
        XCTAssertTrue(store.updateSettings(settings))
        var appearance = store.appearance
        appearance.magnification = magnification
        appearance.magnificationScale = 1.8
        appearance.background = background
        XCTAssertTrue(store.updateAppearance(appearance))
        return store
    }

    private func snapshot(kinds: [DockItemKind], dividers: Set<Int> = [], iconSize: Double = 52) -> DockBarSnapshot {
        var appearance = DockAppearance()
        appearance.magnificationScale = 1.8
        let items = kinds.enumerated().map { index, kind in
            DockBarSnapshot.Item(id: UUID(), kind: kind, title: "item\(index)", iconKey: "\(kind.rawValue):\(index)",
                                 dividerBefore: dividers.contains(index), isRunning: false, badge: nil,
                                 availability: .available, isBouncing: false, isAttentionRequested: false)
        }
        return DockBarSnapshot(items: items, trash: .init(state: .empty, dividerBefore: dividers.contains(kinds.count)),
                               position: .bottom, appearance: appearance, iconSize: iconSize, maximumIconSize: iconSize,
                               magnificationEnabled: true, reduceMotion: false)
    }

    private func panelSize(_ store: DockStore, magnification: Bool) -> CGSize {
        DockPanelSizing.size(
            position: .bottom,
            dockLength: DockMetrics.length(for: store, magnificationEnabled: magnification),
            dockThickness: DockMetrics.thickness(for: store, magnificationEnabled: magnification),
            panelPadding: DockInteractionGeometry.panelPadding * 2, sideLabelGutter: 0, maximumLength: 3000)
    }

    private let iconKinds: [DockItemKind] = [.application, .folder, .application, .file, .application, .link, .application]

    func testBackdropAndTilesMatchSwiftUIMetrics() {
        for size in [16.0, 52, 128] {
            for magnification in [true, false] {
                for kinds in [iconKinds, [.application, .spacer, .application, .clock, .application]] as [[DockItemKind]] {
                    let store = makeStore(kinds: kinds, size: size, magnification: magnification)
                    let snapshot = DockBarSnapshotBuilder.make(store: store)
                    let panel = panelSize(store, magnification: magnification)
                    let count = snapshot.items.count
                    for hovered in [nil, 0, count / 2, count - 1, count] as [Int?] {
                        let label = "size=\(size) mag=\(magnification) kinds=\(kinds) hovered=\(String(describing: hovered))"
                        let frames = DockBarLayout.frames(snapshot: snapshot, minimizedSlots: 0, panelSize: panel, hoveredIndex: hovered)
                        let maximum = magnification ? store.appearance.magnificationScale : 1
                        let expectedLength = min(
                            DockMetrics.backdropLength(for: store, iconSize: size, axisPadding: 5, hoveredIndex: hovered,
                                                       magnificationScale: maximum,
                                                       windowLength: DockMetrics.length(for: store, magnificationEnabled: magnification, iconSize: size)),
                            panel.width - 16)
                        XCTAssertEqual(frames.backdrop.width, expectedLength, accuracy: 0.001, label)
                        XCTAssertEqual(frames.backdrop.height, DockMetrics.backdropThickness(for: store), label)
                        XCTAssertEqual(frames.backdrop.midX, panel.width / 2, accuracy: 0.001, label)
                        XCTAssertEqual(frames.backdrop.minY, DockInteractionGeometry.bottomGap, label)

                        var previous: CGRect?
                        for (index, tile) in frames.tiles.enumerated() {
                            guard let tile else { continue }
                            let scale = DockAppearance.scale(index: index, hovered: hovered, maximum: maximum)
                            XCTAssertEqual(tile.width, size * scale, accuracy: 0.001, label)
                            XCTAssertEqual(tile.height, tile.width, label)
                            XCTAssertEqual(tile.minY, 24, label)
                            if let previous, snapshot.items[index - 1].kind != .spacer, snapshot.items[index - 1].kind != .clock {
                                XCTAssertEqual(tile.minX - previous.maxX, 10, accuracy: 0.001, label)
                            }
                            previous = tile
                        }
                    }
                }
            }
        }
    }

    func testTileRowGrowsSymmetricallyAroundThePanelCenter() {
        let snapshot = snapshot(kinds: Array(repeating: .application, count: 9), dividers: [4])
        let panel = CGSize(width: 1000, height: 120)
        let idle = DockBarLayout.frames(snapshot: snapshot, minimizedSlots: 0, panelSize: panel, hoveredIndex: nil)
        let hovered = DockBarLayout.frames(snapshot: snapshot, minimizedSlots: 0, panelSize: panel, hoveredIndex: 4)
        let growth = CGFloat(52 * (1.8 - 1) + 52 * 0.8 * 0.45 * 2 + 52 * 0.8 * 0.12 * 2)
        let idleWidth = idle.slots.compactMap { $0 }.last!.maxX - idle.slots.compactMap { $0 }.first!.minX
        let hoveredWidth = hovered.slots.compactMap { $0 }.last!.maxX - hovered.slots.compactMap { $0 }.first!.minX
        XCTAssertEqual(hoveredWidth - idleWidth, growth, accuracy: 0.001)
        XCTAssertEqual(hovered.slots.compactMap { $0 }.first!.minX, idle.slots.compactMap { $0 }.first!.minX - growth / 2, accuracy: 0.001)
    }

    func testHoveredIndexFollowsMouseX() {
        let snapshot = snapshot(kinds: [.application, .spacer, .application, .application])
        let frames = DockBarLayout.frames(snapshot: snapshot, minimizedSlots: 0, panelSize: CGSize(width: 800, height: 120), hoveredIndex: nil)
        XCTAssertNil(frames.slots[1])
        for index in [0, 2, 3] {
            let slot = frames.slots[index]!
            XCTAssertEqual(DockBarLayout.hoveredIndex(atX: slot.midX, slots: frames.slots, current: nil), index)
            XCTAssertEqual(DockBarLayout.hoveredIndex(atX: slot.minX, slots: frames.slots, current: nil), index)
        }
        XCTAssertEqual(DockBarLayout.hoveredIndex(atX: frames.slots[0]!.minX - 1, slots: frames.slots, current: 2), 2)
        XCTAssertNil(DockBarLayout.hoveredIndex(atX: frames.slots[0]!.minX - 1, slots: frames.slots, current: nil))
        XCTAssertEqual(DockBarLayout.hoveredIndex(atX: (frames.slots[0]!.maxX + frames.slots[2]!.minX) / 2, slots: frames.slots, current: 0), 0)
    }

    func testStructureChangesOnlyWithIdentityOrIconKeys() {
        let store = makeStore(kinds: iconKinds)
        let base = DockBarSnapshotBuilder.make(store: store)
        XCTAssertEqual(DockBarStructure(snapshot: base), DockBarStructure(snapshot: DockBarSnapshotBuilder.make(store: store)))

        var renamed = base
        renamed = DockBarSnapshot(items: base.items.map { item in
            DockBarSnapshot.Item(id: item.id, kind: item.kind, title: item.title + "!", iconKey: item.iconKey,
                                 dividerBefore: item.dividerBefore, isRunning: !item.isRunning, badge: "1",
                                 availability: item.availability, isBouncing: item.isBouncing,
                                 isAttentionRequested: item.isAttentionRequested)
        }, trash: base.trash, position: base.position, appearance: base.appearance, iconSize: base.iconSize,
                                  maximumIconSize: base.maximumIconSize, magnificationEnabled: base.magnificationEnabled,
                                  reduceMotion: base.reduceMotion)
        XCTAssertEqual(DockBarStructure(snapshot: base), DockBarStructure(snapshot: renamed))

        let rekeyed = DockBarSnapshot(items: base.items.enumerated().map { index, item in
            DockBarSnapshot.Item(id: item.id, kind: item.kind, title: item.title, iconKey: index == 2 ? "other" : item.iconKey,
                                 dividerBefore: item.dividerBefore, isRunning: item.isRunning, badge: item.badge,
                                 availability: item.availability, isBouncing: item.isBouncing,
                                 isAttentionRequested: item.isAttentionRequested)
        }, trash: base.trash, position: base.position, appearance: base.appearance, iconSize: base.iconSize,
                                      maximumIconSize: base.maximumIconSize, magnificationEnabled: base.magnificationEnabled,
                                      reduceMotion: base.reduceMotion)
        XCTAssertNotEqual(DockBarStructure(snapshot: base), DockBarStructure(snapshot: rekeyed))

        let reordered = DockBarSnapshot(items: base.items.reversed(), trash: base.trash, position: base.position,
                                        appearance: base.appearance, iconSize: base.iconSize,
                                        maximumIconSize: base.maximumIconSize, magnificationEnabled: base.magnificationEnabled,
                                        reduceMotion: base.reduceMotion)
        XCTAssertNotEqual(DockBarStructure(snapshot: base), DockBarStructure(snapshot: reordered))
    }

    func testSpringMatchesSwiftUIResponseAndDamping() {
        let parameters = DockBarLayout.springParameters(response: 0.24, dampingFraction: 0.82)
        XCTAssertEqual(parameters.stiffness, 685, accuracy: 1)
        XCTAssertEqual(parameters.damping, 43, accuracy: 0.5)
    }

    func testBackdropStyle() {
        var appearance = DockAppearance()
        appearance.background = .transparent
        XCTAssertEqual(DockBarBackdropStyle(appearance: appearance).fillAlpha, 0)
        XCTAssertEqual(DockBarBackdropStyle(appearance: appearance).borderAlpha, 0)
        appearance.background = .system
        appearance.opacity = 0.5
        let style = DockBarBackdropStyle(appearance: appearance)
        XCTAssertEqual(style.fillAlpha, 0.5)
        XCTAssertEqual(style.borderAlpha, 0.11, accuracy: 0.0001)
        XCTAssertEqual(style.shadowOpacity, 0.18)
        appearance.background = .appleDock
        XCTAssertEqual(DockBarBackdropStyle(appearance: appearance).shadowOpacity, 0)
    }

    func testRendererFlag() {
        let suite = UserDefaults(suiteName: "DockBarLayoutTests-\(UUID().uuidString)")!
        XCTAssertFalse(DockBarRenderer.isLayerEnabled(defaults: suite, environment: [:]))
        XCTAssertTrue(DockBarRenderer.isLayerEnabled(defaults: suite, environment: [DockBarRenderer.environmentKey: "1"]))
        XCTAssertFalse(DockBarRenderer.isLayerEnabled(defaults: suite, environment: [DockBarRenderer.environmentKey: "0"]))
        suite.set(true, forKey: DockBarRenderer.defaultsKey)
        XCTAssertTrue(DockBarRenderer.isLayerEnabled(defaults: suite, environment: [:]))
        XCTAssertTrue(DockBarRenderer.usesLayerBar(enabled: true, position: .bottom))
        XCTAssertFalse(DockBarRenderer.usesLayerBar(enabled: true, position: .left))
        XCTAssertFalse(DockBarRenderer.usesLayerBar(enabled: false, position: .bottom))
    }

    func testViewHoverClickAndAccessibility() {
        let snapshot = snapshot(kinds: [.application, .spacer, .application, .application])
        let view = DockBarView(frame: NSRect(x: 0, y: 0, width: 800, height: 120))
        var clicks: [(UUID, NSEvent.ModifierFlags)] = []
        view.onClick = { clicks.append(($0, $1)) }
        view.apply(snapshot: snapshot, minimizedSlots: 0)
        XCTAssertEqual(view.tileCount, 3)
        XCTAssertEqual((view.accessibilityChildren() as? [NSAccessibilityElement])?.map { $0.accessibilityIdentifier() },
                       ["dockbar-tile-0", "dockbar-tile-2", "dockbar-tile-3"])

        let frames = DockBarLayout.frames(snapshot: snapshot, minimizedSlots: 0, panelSize: view.bounds.size, hoveredIndex: nil)
        func event(_ type: NSEvent.EventType, at point: CGPoint, flags: NSEvent.ModifierFlags = []) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: point, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                               context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        let target = CGPoint(x: frames.slots[2]!.midX, y: 30)
        view.mouseMoved(with: event(.mouseMoved, at: target))
        XCTAssertEqual(view.hoveredIndex, 2)
        view.mouseExited(with: event(.mouseMoved, at: target))
        XCTAssertNil(view.hoveredIndex)

        view.mouseDown(with: event(.leftMouseDown, at: target))
        view.mouseUp(with: event(.leftMouseUp, at: target, flags: .command))
        XCTAssertEqual(clicks.count, 1)
        XCTAssertEqual(clicks.first?.0, snapshot.items[2].id)
        XCTAssertEqual(clicks.first?.1, .command)

        view.mouseDown(with: event(.leftMouseDown, at: target))
        view.mouseUp(with: event(.leftMouseUp, at: CGPoint(x: frames.slots[3]!.midX, y: 30)))
        XCTAssertEqual(clicks.count, 1)
    }
}
