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

    func testColorModeDefaultsToSystemAndRoundTrips() throws {
        let legacy = try JSONDecoder().decode(DockAppearance.self, from: Data("{\"background\":\"color\",\"color\":3158064}".utf8))
        XCTAssertEqual(legacy.colorMode, .system)
        XCTAssertEqual(legacy.background, .color)
        XCTAssertEqual(legacy.color, 0x303030)
        var value = DockAppearance()
        value.colorMode = .light
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(DockAppearance.self, from: data).colorMode, .light)
        XCTAssertThrowsError(try JSONDecoder().decode(DockAppearance.self, from: Data("{\"colorMode\":\"sepia\"}".utf8)))
    }

    func testColorModeResolvesToSystemOrExplicitAppearance() {
        XCTAssertNil(DockAppearance.ColorMode.system.colorScheme)
        XCTAssertNil(DockAppearance.ColorMode.system.nsAppearance)
        XCTAssertEqual(DockAppearance.ColorMode.light.colorScheme, .light)
        XCTAssertEqual(DockAppearance.ColorMode.dark.colorScheme, .dark)
        XCTAssertEqual(DockAppearance.ColorMode.light.nsAppearance?.name, .aqua)
        XCTAssertEqual(DockAppearance.ColorMode.dark.nsAppearance?.name, .darkAqua)
    }

    func testColorModeKeepsUserColorAndImage() throws {
        let root = try directory()
        let persistence = ProfilePersistence(fileURL: root.appendingPathComponent("profiles.json"))
        let store = DockStore(persistence: persistence)
        var value = DockAppearance()
        value.background = .color
        value.color = 0x112233
        value.image = "/tmp/background.png"
        value.colorMode = .dark
        XCTAssertTrue(store.updateAppearance(value))
        value.colorMode = .light
        XCTAssertTrue(store.updateAppearance(value))
        let restored = DockStore(persistence: persistence).appearance
        XCTAssertEqual(restored.colorMode, .light)
        XCTAssertEqual(restored.color, 0x112233)
        XCTAssertEqual(restored.image, "/tmp/background.png")
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

    func testAppleDockPresetRestoresPreviousCustomBackgroundValues() throws {
        let root = try directory()
        let persistence = ProfilePersistence(fileURL: root.appendingPathComponent("profiles.json"))
        let store = DockStore(persistence: persistence)
        var value = DockAppearance()
        value.opacity = 0.2
        value.blur = false
        value.color = 0x123456
        value.background = .appleDock
        XCTAssertTrue(store.updateAppearance(value))
        let restored = DockStore(persistence: persistence)
        XCTAssertEqual(restored.appearance, value)
        restored.stageAppearance(\.background, value: .color)
        XCTAssertTrue(restored.finishAppearanceEditing())
        let custom = DockStore(persistence: persistence).appearance
        XCTAssertEqual(custom.background, .color)
        XCTAssertEqual(custom.opacity, 0.2)
        XCTAssertFalse(custom.blur)
        XCTAssertEqual(custom.color, 0x123456)
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

    func testControlShiftTemporarilyTogglesMagnificationWithoutChangingPreference() {
        XCTAssertTrue(DockTemporaryMagnification.isMagnified(configured: true, modifiersHeld: false))
        XCTAssertFalse(DockTemporaryMagnification.isMagnified(configured: true, modifiersHeld: true))
        XCTAssertFalse(DockTemporaryMagnification.isMagnified(configured: false, modifiersHeld: false))
        XCTAssertTrue(DockTemporaryMagnification.isMagnified(configured: false, modifiersHeld: true))
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
        XCTAssertLessThan(color.alphaComponent, 0.1)
    }

    func testGlassForegroundLeavesDarkBaseTransparentAndKeepsBrightDetails() {
        let dark = DockIconRenderer.transformed(red: 16, green: 16, blue: 16, alpha: 255, style: .glass, backgroundBrightness: 16.0 / 255)
        let detail = DockIconRenderer.transformed(red: 240, green: 240, blue: 240, alpha: 255, style: .glass, backgroundBrightness: 16.0 / 255)
        XCTAssertLessThan(dark.3, 16)
        XCTAssertGreaterThan(detail.3, 100)
        XCTAssertLessThan(detail.3, 200)
        XCTAssertEqual(detail.0, detail.3)
        XCTAssertEqual(detail.1, detail.3)
        XCTAssertEqual(detail.2, detail.3)
    }

    func testGlassDarkGlyphsKeepAlphaAndDrawBlack() throws {
        let image = NSImage(size: NSSize(width: 32, height: 32), flipped: false) { rect in
            NSColor.black.setFill()
            rect.fill()
            NSColor.white.setFill()
            NSRect(x: 8, y: 8, width: 16, height: 16).fill()
            return true
        }
        func detail(darkGlyphs: Bool) throws -> NSColor {
            let converted = DockIconRenderer.render(image, style: .glass, pixels: 32, darkGlyphs: darkGlyphs)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(converted.tiffRepresentation)))
            return try XCTUnwrap(bitmap.colorAt(x: 16, y: 16)?.usingColorSpace(.deviceRGB))
        }
        let light = try detail(darkGlyphs: false)
        let dark = try detail(darkGlyphs: true)
        XCTAssertGreaterThan(light.redComponent, 0.9)
        XCTAssertLessThan(dark.redComponent, 0.05)
        XCTAssertEqual(light.alphaComponent, dark.alphaComponent, accuracy: 0.02)
        XCTAssertGreaterThan(dark.alphaComponent, 0.5)
    }

    func testGlassKeepsDetailsVisibleOnBothLightAndDarkIconBases() throws {
        for lightBackground in [true, false] {
            let image = NSImage(size: NSSize(width: 32, height: 32), flipped: false) { rect in
                (lightBackground ? NSColor.white : .black).setFill()
                rect.fill()
                (lightBackground ? NSColor.black : .white).setFill()
                NSRect(x: 8, y: 8, width: 16, height: 16).fill()
                return true
            }
            let converted = DockIconRenderer.render(image, style: .glass, pixels: 32)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(converted.tiffRepresentation)))
            XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: 3, y: 3)).alphaComponent, 0.1)
            XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x: 16, y: 16)).alphaComponent, 0.5)
        }
    }

    func testIconConversionResolutionTracksDisplayedSizeAndBackingScale() {
        XCTAssertEqual(DockIconConversionPolicy.pixelSize(pointSize: 128, backingScaleFactor: 2), 256)
        XCTAssertEqual(DockIconConversionPolicy.pixelSize(pointSize: 256, backingScaleFactor: 2), 512)
        XCTAssertEqual(DockIconConversionPolicy.pixelSize(pointSize: 128, backingScaleFactor: 1), 256)
        XCTAssertEqual(DockIconConversionPolicy.pixelSize(pointSize: 16.1, backingScaleFactor: 2), 33)
    }

    func testIconConversionCacheKeysSeparateStylesAndGlassSchemes() {
        let darkGlass = DockIconConversionPolicy.cacheKey(path: "/Applications/Example.app", style: "glass", darkGlyphs: false)
        let lightGlass = DockIconConversionPolicy.cacheKey(path: "/Applications/Example.app", style: "glass", darkGlyphs: true)
        let monochrome = DockIconConversionPolicy.cacheKey(path: "/Applications/Example.app", style: "monochrome", darkGlyphs: false)
        XCTAssertNotEqual(darkGlass, lightGlass)
        XCTAssertNotEqual(darkGlass, monochrome)
    }

    func testIconConversionCacheLimitFitsMoreThanSixteenMaxSizeIcons() {
        let maximumResolutionCost = DockIconConversionPolicy.cacheCost(pixels: 512)
        XCTAssertEqual(maximumResolutionCost, 1_048_576)
        XCTAssertGreaterThanOrEqual(DockIconConversionPolicy.cacheTotalCostLimit(), maximumResolutionCost * 17)
        XCTAssertGreaterThanOrEqual(DockIconConversionPolicy.cacheCountLimit(), 17)
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

    func testBottomDockKeepsFivePointGapWhenSystemDockReservesSpace() {
        let size = NSSize(width: 480, height: 160)
        for screen in [NSRect(x: 0, y: 0, width: 1600, height: 1000),
                       NSRect(x: -1920, y: -1080, width: 1920, height: 1080)] {
            for reservedHeight in [0.0, 85.0] {
                let available = NSRect(x: screen.minX, y: screen.minY + reservedHeight,
                                       width: screen.width, height: screen.height - reservedHeight - 30)
                    .insetBy(dx: 10, dy: 10)
                let origin = DockInteractionGeometry.panelOrigin(screen: screen, available: available,
                                                                 size: size, position: .bottom)
                XCTAssertEqual(origin.y + DockInteractionGeometry.panelPadding, screen.minY + 5)
                XCTAssertEqual(origin.x + size.width / 2, screen.midX)
            }
        }
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
