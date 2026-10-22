import XCTest
@testable import DockStudio

final class DockBackdropFitTests: XCTestCase {
    func testBottomBackdropHugsIcon() {
        for (size, expected) in [(16.0, 45.0), (52.0, 81.0), (128.0, 157.0)] {
            XCTAssertEqual(DockBackdropFit.bottomThickness(iconSize: size, hasTile: false), CGFloat(expected))
        }
    }

    func testBottomBackdropKeepsRoomForTiles() {
        XCTAssertEqual(DockBackdropFit.bottomThickness(iconSize: 16, hasTile: true), 74)
        XCTAssertEqual(DockBackdropFit.bottomThickness(iconSize: 128, hasTile: true), 157)
    }

    func testSideBackdropHugsIcon() {
        for (size, expected) in [(16.0, 40.0), (52.0, 76.0), (128.0, 152.0)] {
            XCTAssertEqual(DockBackdropFit.sideThickness(iconSize: size, hasTile: false), CGFloat(expected))
        }
        XCTAssertEqual(DockBackdropFit.sideThickness(iconSize: 52, hasTile: true), 164)
    }

    @MainActor
    func testBackdropStaysInsideWindowWithMagnificationOnAndOff() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DockStore(persistence: ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json")))
        for position in [DockPosition.bottom, .left] {
            for size in [16.0, 52, 128] {
                var settings = store.document.settings
                settings.iconSize = size
                settings.position = position
                XCTAssertTrue(store.updateSettings(settings))
                let backdrop = DockMetrics.backdropThickness(for: store)
                for enabled in [true, false] {
                    let window = DockMetrics.thickness(for: store, magnificationEnabled: enabled)
                    XCTAssertLessThanOrEqual(backdrop, window, "\(position) \(size) magnification=\(enabled)")
                }
                let hug = position == .bottom
                    ? DockBackdropFit.bottomThickness(iconSize: size, hasTile: false)
                    : DockBackdropFit.sideThickness(iconSize: size, hasTile: false)
                XCTAssertEqual(backdrop, hug, accuracy: 0.001, "\(position) \(size)")
            }
        }
    }
}
