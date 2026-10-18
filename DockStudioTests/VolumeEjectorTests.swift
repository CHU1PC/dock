import XCTest
@testable import DockStudio

final class VolumeEjectorTests: XCTestCase {
    func testOnlyEjectableVolumeRootFolderIsAccepted() {
        let volumeURL = URL(fileURLWithPath: "/Volumes/Backup")
        let ejector = VolumeEjector(metadata: { _ in
            EjectableVolumeMetadata(isDirectory: true, isEjectable: true, volumeURL: volumeURL)
        }, eject: { _ in })

        XCTAssertTrue(ejector.isEjectable(folder("/Volumes/Backup")))
        XCTAssertFalse(ejector.isEjectable(folder("/Volumes/Backup/Projects")))
        XCTAssertFalse(ejector.isEjectable(file("/Volumes/Backup")))
        XCTAssertFalse(ejector.isEjectable(folder("/")))
    }

    func testNonEjectableAndUnknownVolumesAreRejected() {
        let volumeURL = URL(fileURLWithPath: "/Volumes/Backup")
        let notEjectable = VolumeEjector(metadata: { _ in
            EjectableVolumeMetadata(isDirectory: true, isEjectable: false, volumeURL: volumeURL)
        }, eject: { _ in })
        let unknown = VolumeEjector(metadata: { _ in nil }, eject: { _ in })

        XCTAssertFalse(notEjectable.isEjectable(folder("/Volumes/Backup")))
        XCTAssertFalse(unknown.isEjectable(folder("/Volumes/Backup")))
    }

    func testEjectionUsesInjectedOperationAndPropagatesFailure() {
        enum Failure: Error { case busy }
        var ejected: URL?
        let url = URL(fileURLWithPath: "/Volumes/Backup")
        let ejector = VolumeEjector(metadata: { _ in nil }, eject: { target in
            ejected = target
            throw Failure.busy
        })

        XCTAssertThrowsError(try ejector.ejectVolume(at: url))
        XCTAssertEqual(ejected, url)
    }

    private func folder(_ path: String) -> DockItem {
        DockItem(name: "Disk", kind: .folder, target: URL(fileURLWithPath: path).absoluteString)
    }

    private func file(_ path: String) -> DockItem {
        DockItem(name: "Disk", kind: .file, target: URL(fileURLWithPath: path).absoluteString)
    }
}
