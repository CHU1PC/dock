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

    func testBottomLengthHugsItemsAndTrash() {
        let content = DockBackdropFit.LengthContent(iconItems: 5, fixedExtent: 0, minimizedSlots: 0)
        for (size, expected) in [(16.0, 196.0), (52.0, 412.0), (128.0, 868.0)] {
            XCTAssertEqual(DockBackdropFit.length(content, iconSize: size, axisPadding: 5, vertical: false),
                           CGFloat(expected))
        }
    }

    func testSideLengthCountsItemExtraAndFixedItems() {
        let content = DockBackdropFit.LengthContent(iconItems: 2, fixedExtent: 22 + 64, minimizedSlots: 1)
        let expected: CGFloat = 86 + 105 + 26 + 30 + 14
        XCTAssertEqual(DockBackdropFit.length(content, iconSize: 16, axisPadding: 5, vertical: true), expected)
    }

    func testLengthMarginMatchesThicknessMargin() {
        let content = DockBackdropFit.LengthContent(iconItems: 0, fixedExtent: 0, minimizedSlots: 0)
        let bottom = DockBackdropFit.length(content, iconSize: 16, axisPadding: 5, vertical: false)
        XCTAssertEqual(bottom, 66)
        let shrunk = DockBackdropFit.length(content, iconSize: 16, axisPadding: 2, vertical: false)
        XCTAssertEqual(shrunk, 66)
    }

    @MainActor
    func testBackdropLengthStaysInsideWindowLength() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DockStore(persistence: ProfilePersistence(fileURL: directory.appendingPathComponent("profiles.json")))
        for position in [DockPosition.bottom, .left] {
            for size in [16.0, 52, 128] {
                var settings = store.document.settings
                settings.iconSize = size
                settings.position = position
                XCTAssertTrue(store.updateSettings(settings))
                let backdrop = DockMetrics.backdropLength(for: store, iconSize: size, axisPadding: 5)
                for enabled in [true, false] {
                    let window = DockMetrics.length(for: store, magnificationEnabled: enabled)
                    XCTAssertLessThanOrEqual(backdrop, window, "\(position) \(size) magnification=\(enabled)")
                }
            }
        }
    }
}
