import XCTest
@testable import DockStudio

final class ItemAvailabilityTests: XCTestCase {
    private func item(_ kind: DockItemKind = .file, path: String? = "/Users/me/a.txt") -> DockItem {
        DockItem(name: "x", kind: kind, target: path.map { URL(fileURLWithPath: $0).absoluteString })
    }

    private func checker(_ table: [String: Int32]) -> ItemAvailabilityChecker {
        ItemAvailabilityChecker(probe: { table[$0] ?? ENOENT })
    }

    func testExistingTargetIsAvailable() {
        XCTAssertEqual(checker(["/Users/me/a.txt": 0]).check(item()), .available)
    }

    func testMissingTargetIsMissing() {
        XCTAssertEqual(checker([:]).check(item()), .missing)
        XCTAssertEqual(checker(["/Users/me/a.txt": ENOTDIR]).check(item()), .missing)
    }

    func testUnsetTargetIsMissing() {
        XCTAssertEqual(checker([:]).check(item(path: nil)), .missing)
    }

    func testPermissionDeniedAndOtherErrorsAreNotMissing() {
        for code in [EACCES, EPERM, EIO, ETIMEDOUT] {
            let result = checker(["/Users/me/a.txt": code]).check(item())
            XCTAssertEqual(result, .inaccessible)
            XCTAssertFalse(result.isUnavailable)
        }
    }

    func testUnmountedVolumeIsDistinguishedFromMissingFile() {
        let path = "/Volumes/Disk/docs/a.txt"
        XCTAssertEqual(checker([:]).check(item(path: path)), .volumeNotMounted)
        XCTAssertEqual(checker(["/Volumes/Disk": 0]).check(item(path: path)), .missing)
        XCTAssertEqual(checker(["/Volumes/Disk": EACCES]).check(item(path: path)), .inaccessible)
        XCTAssertEqual(checker(["/Volumes/Disk": 0, path: 0]).check(item(path: path)), .available)
    }

    func testVolumeRootItselfMissingIsVolumeNotMounted() {
        XCTAssertEqual(checker([:]).check(item(.folder, path: "/Volumes/Disk")), .missing)
    }

    func testItemsWithoutFileTargetsAreAlwaysAvailable() {
        let always = checker([:])
        XCTAssertEqual(always.check(DockItem(name: "c", kind: .clock)), .available)
        XCTAssertEqual(always.check(DockItem(name: "s", kind: .spacer)), .available)
        XCTAssertEqual(always.check(DockItem(name: "l", kind: .link, target: "https://example.com")), .available)
    }

    func testRealFilesystemTransitions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("a.txt")
        let target = item(path: file.path)
        let real = ItemAvailabilityChecker()
        XCTAssertEqual(real.check(target), .missing)
        try "x".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertEqual(real.check(target), .available)
        let link = directory.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory.appendingPathComponent("gone"))
        XCTAssertEqual(real.check(item(path: link.path)), .missing)
    }

    @MainActor
    func testMonitorCacheIsKeyedByTargetAndDoesNotRemoveItems() async {
        let missing = item(path: "/nonexistent/\(UUID().uuidString)")
        let monitor = ItemAvailabilityMonitor(allItems: { [missing] })
        XCTAssertEqual(monitor.status(of: missing), .available)
        await monitor.refreshAll()
        XCTAssertEqual(monitor.status(of: missing), .missing)
        var reselected = missing
        reselected.target = URL(fileURLWithPath: "/tmp").absoluteString
        XCTAssertEqual(monitor.status(of: reselected), .available)
    }

    @MainActor
    func testOpeningMissingItemKeepsItInProfile() {
        let store = DockStore.preview()
        let missing = item(.folder, path: "/nonexistent/\(UUID().uuidString)")
        store.addItem(missing)
        let before = store.activeProfile.items
        store.itemAvailability.record(missing, .missing)
        XCTAssertEqual(store.activeProfile.items, before)
        XCTAssertTrue(store.itemAvailability.status(of: missing).isUnavailable)
    }
}
