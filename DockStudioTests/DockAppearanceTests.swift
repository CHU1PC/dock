import XCTest
import AppKit
@testable import DockStudio

@MainActor
final class DockAppearanceTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testPartialGPUIAppearanceUsesCompatibleDefaults() throws {
        let appearance = try JSONDecoder().decode(DockAppearance.self, from: Data("{\"iconStyle\":\"glass\",\"opacity\":0.3}".utf8))
        XCTAssertEqual(appearance.iconStyle, .glass)
        XCTAssertEqual(appearance.opacity, 0.3)
        XCTAssertEqual(appearance.background, .system)
        XCTAssertTrue(appearance.magnification)
    }

    func testUnknownAppearanceIsProtectedWithoutBlockingProfiles() throws {
        let root = try directory()
        let file = root.appendingPathComponent("appearance.json")
        let original = Data("{\"futureEffect\":true}".utf8)
        try original.write(to: file)
        let store = DockStore(persistence: ProfilePersistence(fileURL: root.appendingPathComponent("profiles.json")))
        XCTAssertTrue(store.appearanceIsReadOnly)
        XCTAssertFalse(store.storageIsReadOnly)
        XCTAssertFalse(store.updateAppearance(DockAppearance()))
        XCTAssertEqual(try Data(contentsOf: file), original)
        store.createProfile()
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("profiles.json").path))
    }

    func testCorruptAppearanceCanBeRetriedAfterUserRepairsFile() throws {
        let root = try directory()
        let file = root.appendingPathComponent("appearance.json")
        try Data("not json".utf8).write(to: file)
        let store = DockStore(persistence: ProfilePersistence(fileURL: root.appendingPathComponent("profiles.json")))
        XCTAssertTrue(store.appearanceIsReadOnly)
        try JSONEncoder().encode(DockAppearance()).write(to: file)
        store.retryAppearance()
        XCTAssertFalse(store.appearanceIsReadOnly)
        XCTAssertNil(store.appearanceLoadError)
    }

    func testAppearanceRoundTripAndValidation() throws {
        let root = try directory()
        let persistence = ProfilePersistence(fileURL: root.appendingPathComponent("profiles.json"))
        let store = DockStore(persistence: persistence)
        var value = DockAppearance()
        value.background = .transparent
        value.iconStyle = .monochrome
        value.magnificationScale = 1.8
        XCTAssertTrue(store.updateAppearance(value))
        XCTAssertEqual(DockStore(persistence: persistence).appearance, value)
        value.opacity = .nan
        XCTAssertFalse(store.updateAppearance(value))
        XCTAssertEqual(store.appearance.opacity, 0.55)
    }

    func testFailedWriteDoesNotApplyUnsavedAppearance() throws {
        let root = try directory()
        let blocked = root.appendingPathComponent("blocked")
        try Data().write(to: blocked)
        let store = DockStore(persistence: ProfilePersistence(fileURL: blocked.appendingPathComponent("profiles.json")))
        var value = DockAppearance()
        value.background = .transparent
        XCTAssertFalse(store.updateAppearance(value))
        XCTAssertEqual(store.appearance, DockAppearance())
    }

    func testMagnificationFallsOffAndRespectsDisabledState() {
        XCTAssertEqual(DockAppearance.scale(index: 3, hovered: 3, maximum: 2), 2)
        XCTAssertEqual(DockAppearance.scale(index: 2, hovered: 3, maximum: 2), 1.45, accuracy: 0.0001)
        XCTAssertEqual(DockAppearance.scale(index: 1, hovered: 3, maximum: 2), 1.12, accuracy: 0.0001)
        XCTAssertEqual(DockAppearance.scale(index: 0, hovered: 3, maximum: 2), 1)
        XCTAssertEqual(DockAppearance.scale(index: 3, hovered: nil, maximum: 2), 1)
        XCTAssertEqual(DockAppearance.scale(index: 3, hovered: 3, maximum: 1), 1)
    }

    func testMonochromePreservesAlphaAndGlassRemainsPremultiplied() {
        let mono = DockIconRenderer.transformed(red: 100, green: 30, blue: 10, alpha: 128, style: .monochrome)
        XCTAssertEqual(mono.0, mono.1)
        XCTAssertEqual(mono.1, mono.2)
        XCTAssertEqual(mono.3, 128)
        let glass = DockIconRenderer.transformed(red: 100, green: 30, blue: 10, alpha: 128, style: .glass)
        XCTAssertLessThan(glass.3, 128)
        XCTAssertLessThanOrEqual(glass.0, glass.3)
        let empty = DockIconRenderer.transformed(red: 0, green: 0, blue: 0, alpha: 0, style: .glass)
        XCTAssertEqual(empty.0, 0)
        XCTAssertEqual(empty.3, 0)
    }
    func testStagedAppearanceIsSavedOnlyWhenFinished() throws {
        let root = try directory()
        let store = DockStore(persistence: ProfilePersistence(fileURL: root.appendingPathComponent("profiles.json")))
        store.stageAppearance(\.opacity, value: 0.8)
        XCTAssertEqual(store.appearance.opacity, 0.8)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("appearance.json").path))
        XCTAssertTrue(store.finishAppearanceEditing())
        let restored = DockStore(persistence: ProfilePersistence(fileURL: root.appendingPathComponent("profiles.json")))
        XCTAssertEqual(restored.appearance.opacity, 0.8)
    }

    func testAnotherWritersAppearanceIsPreservedUntilReload() throws {
        let root = try directory()
        let persistence = ProfilePersistence(fileURL: root.appendingPathComponent("profiles.json"))
        let first = DockStore(persistence: persistence)
        let second = DockStore(persistence: persistence)
        var next = DockAppearance()
        next.opacity = 0.3
        XCTAssertTrue(first.updateAppearance(next))
        XCTAssertFalse(second.updateAppearance(DockAppearance()))
        XCTAssertTrue(second.appearanceIsReadOnly)
        XCTAssertEqual(DockStore(persistence: persistence).appearance.opacity, 0.3)
        second.retryAppearance()
        XCTAssertFalse(second.appearanceIsReadOnly)
        XCTAssertTrue(second.updateAppearance(DockAppearance()))
    }

    func testActualBitmapConversionPreservesTransparencyAndGray() throws {
        let image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            NSColor.red.withAlphaComponent(0.5).setFill()
            rect.fill()
            return true
        }
        let result = DockIconRenderer.render(image, style: .glass, pixels: 32)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(result.tiffRepresentation)))
        let color = try XCTUnwrap(bitmap.colorAt(x: 16, y: 16)?.usingColorSpace(.deviceRGB))
        XCTAssertEqual(color.redComponent, color.greenComponent, accuracy: 0.01)
        XCTAssertEqual(color.greenComponent, color.blueComponent, accuracy: 0.01)
        XCTAssertEqual(color.alphaComponent, 0.36, accuracy: 0.02)
    }

    func testRevealReachesPhysicalScreenEdgesAndKeepsOtherRegionsClear() {
        let screen = NSRect(x: -1920, y: -1080, width: 1920, height: 1080)
        let panel = NSRect(x: -1100, y: -1070, width: 350, height: 160)
        let bottom = DockInteractionGeometry.reveal(screen: screen, panel: panel, position: .bottom)
        XCTAssertTrue(bottom.contains(NSPoint(x: -1000, y: -1080)))
        XCTAssertFalse(bottom.contains(NSPoint(x: -1800, y: -1080)))
        let leftPanel = NSRect(x: -1910, y: -600, width: 190, height: 350)
        XCTAssertTrue(DockInteractionGeometry.reveal(screen: screen, panel: leftPanel, position: .left)
            .contains(NSPoint(x: -1920, y: -500)))
        let rightPanel = NSRect(x: -200, y: -600, width: 190, height: 350)
        XCTAssertTrue(DockInteractionGeometry.reveal(screen: screen, panel: rightPanel, position: .right)
            .contains(NSPoint(x: -0.1, y: -500)))
    }

    func testMaximumVerticalMagnificationFitsWithinPanel() {
        let store = DockStore.preview()
        var settings = store.document.settings
        settings.position = .left
        settings.iconSize = 76
        XCTAssertTrue(store.updateSettings(settings))
        var appearance = store.appearance
        appearance.magnificationScale = 2
        XCTAssertTrue(store.updateAppearance(appearance))
        XCTAssertGreaterThanOrEqual(DockMetrics.thickness(for: store), 76 * 2 + 24)
    }

    func testBackgroundImportAndCleanupKeepSourceAndUnmanagedFiles() throws {
        let root = try directory()
        let source = root.appendingPathComponent("source.png")
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 32, bitsPerPixel: 32))
        bitmap.bitmapData?.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: source)
        let imported = try DockBackgroundAssets.importImage(source, directory: root)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported))
        DockBackgroundAssets.removeManagedImage(source.path, directory: root)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        DockBackgroundAssets.removeManagedImage(imported, directory: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: imported))
        let invalid = root.appendingPathComponent("invalid.png")
        try Data("invalid".utf8).write(to: invalid)
        XCTAssertThrowsError(try DockBackgroundAssets.importImage(invalid, directory: root))
    }

    func testManagedBackgroundCanBeResolvedAfterMovingDataDirectory() throws {
        let root = try directory()
        let folder = root.appendingPathComponent("backgrounds")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".png"
        let moved = folder.appendingPathComponent(name)
        try Data().write(to: moved)
        var appearance = DockAppearance()
        appearance.image = "/old/location/backgrounds/" + name
        let original = try JSONEncoder().encode(appearance)
        let file = root.appendingPathComponent("appearance.json")
        try original.write(to: file)
        let store = DockStore(persistence: ProfilePersistence(fileURL: root.appendingPathComponent("profiles.json")))
        XCTAssertEqual(store.appearance.image, moved.path)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

}
