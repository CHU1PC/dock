import XCTest
@testable import DockStudio

@MainActor
final class DockMetricsInputTests: XCTestCase {
    private func makeStore(extraKinds: [DockItemKind], arrangement: DockArrangement) -> DockStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = DockStore(persistence: ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json")))
        for (index, kind) in extraKinds.enumerated() {
            store.addItem(DockItem(name: "item\(index)", kind: kind, target: nil, bundleIdentifier: "com.example.\(index)"))
        }
        var settings = store.document.settings
        settings.arrangement = arrangement
        XCTAssertTrue(store.updateSettings(settings))
        return store
    }

    func testStoreAndInputResultsAreEqual() {
        let layouts: [([DockItemKind], DockArrangement)] = [
            ([], .free),
            ([.application, .spacer, .clock], .free),
            ([.application, .file, .folder, .focusTimer, .clock, .link], .standardSections),
        ]
        var sawDivider = false
        for (kinds, arrangement) in layouts {
            let store = makeStore(extraKinds: kinds, arrangement: arrangement)
            for position in [DockPosition.bottom, .left, .right] {
                for size in [16.0, 52, 128] {
                    for background in [DockAppearance.Background.system, .appleDock] {
                        var settings = store.document.settings
                        settings.position = position
                        settings.iconSize = size
                        XCTAssertTrue(store.updateSettings(settings))
                        var appearance = store.appearance
                        appearance.background = background
                        XCTAssertTrue(store.updateAppearance(appearance))
                        for magnification in [true, false] {
                            appearance.magnification = magnification
                            appearance.magnificationScale = 1.8
                            XCTAssertTrue(store.updateAppearance(appearance))
                            let input = DockMetricsInput(store: store)
                            sawDivider = sawDivider || !input.dividerBefore.isEmpty
                            let label = "\(kinds) \(position) \(size) \(background) mag=\(magnification)"
                            assertEqual(store: store, input: input, label: label)
                        }
                    }
                }
            }
        }
        XCTAssertTrue(sawDivider)
    }

    private func assertEqual(store: DockStore, input: DockMetricsInput, label: String) {
        for override in [nil, true, false] as [Bool?] {
            XCTAssertEqual(DockMetrics.length(for: store, magnificationEnabled: override),
                           DockMetrics.length(for: input, magnificationEnabled: override), label)
            XCTAssertEqual(DockMetrics.length(for: store, magnificationEnabled: override, iconSize: 40),
                           DockMetrics.length(for: input, magnificationEnabled: override, iconSize: 40), label)
            XCTAssertEqual(DockMetrics.barThickness(for: store, magnificationEnabled: override),
                           DockMetrics.barThickness(for: input, magnificationEnabled: override), label)
            XCTAssertEqual(DockMetrics.thickness(for: store, magnificationEnabled: override),
                           DockMetrics.thickness(for: input, magnificationEnabled: override), label)
            XCTAssertEqual(DockMetrics.verticalFitContent(for: store, magnificationEnabled: override),
                           DockMetrics.verticalFitContent(for: input, magnificationEnabled: override), label)
            for available in [nil, 200, 400, 900] as [CGFloat?] {
                for forceFit in [false, true] {
                    XCTAssertEqual(
                        DockMetrics.effectiveIconSize(for: store, availableLength: available,
                                                      magnificationEnabled: override, forceFit: forceFit),
                        DockMetrics.effectiveIconSize(for: input, availableLength: available,
                                                      magnificationEnabled: override, forceFit: forceFit), label)
                }
            }
        }
        XCTAssertEqual(DockMetrics.backdropThickness(for: store), DockMetrics.backdropThickness(for: input), label)
        for hovered in [nil, 0, 2, 99] as [Int?] {
            for scale in [1.0, 1.45, 2.0] {
                for window in [CGFloat.infinity, 300] {
                    XCTAssertEqual(
                        DockMetrics.backdropLength(for: store, iconSize: 40, axisPadding: 12, hoveredIndex: hovered,
                                                   magnificationScale: scale, windowLength: window),
                        DockMetrics.backdropLength(for: input, iconSize: 40, axisPadding: 12, hoveredIndex: hovered,
                                                   magnificationScale: scale, windowLength: window), label)
                }
            }
        }
    }
}
