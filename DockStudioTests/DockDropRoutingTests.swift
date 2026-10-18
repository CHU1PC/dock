import XCTest
@testable import DockStudio

final class DockDropRoutingTests: XCTestCase {
    func testRoutesInsertionApplicationAndTrashTargets() {
        let app = DockItem(name: "TextEdit", kind: .application, target: "file:///Applications/TextEdit.app/")

        XCTAssertEqual(DockDropRouting.decision(for: .insertion(3)), .insert(at: 3))
        XCTAssertEqual(DockDropRouting.decision(for: .application(app)), .openWithApplication(app))
        XCTAssertEqual(DockDropRouting.decision(for: .trash), .moveToTrash)
    }

    func testUnavailableOrMissingFolderIsRefused() {
        let missing = URL(fileURLWithPath: "/tmp/missing-folder-\(UUID().uuidString)")

        XCTAssertEqual(DockDropRouting.decision(for: .folder(missing), folderIsAvailable: false),
                       .refuse("フォルダを利用できません。"))
        XCTAssertEqual(DockDropRouting.decision(for: .folder(nil)), .refuse("フォルダを利用できません。"))
    }

    func testRefusesFolderDroppedOntoItselfOrItsDescendant() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let descendant = source.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: descendant, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertEqual(DockDropRouting.decision(for: .folder(source), source: source),
                       .refuse("フォルダ自身またはその子孫への移動はできません。"))
        XCTAssertEqual(DockDropRouting.decision(for: .folder(descendant), source: source),
                       .refuse("フォルダ自身またはその子孫への移動はできません。"))
    }

    func testFolderMoveReportsEachFailureAndContinues() {
        enum MoveError: LocalizedError {
            case collision
            var errorDescription: String? { "File exists" }
        }
        let first = URL(fileURLWithPath: "/tmp/collision.txt")
        let second = URL(fileURLWithPath: "/tmp/allowed.txt")
        var attempted: [(URL, URL)] = []

        let failures = FolderDropService.move([first, second], into: URL(fileURLWithPath: "/tmp/folder")) { source, target in
            attempted.append((source, target))
            if source == first { throw MoveError.collision }
        }

        XCTAssertEqual(attempted.map(\.0), [first, second])
        XCTAssertEqual(attempted.map(\.1), [
            URL(fileURLWithPath: "/tmp/folder/collision.txt"),
            URL(fileURLWithPath: "/tmp/folder/allowed.txt")
        ])
        XCTAssertEqual(failures, [FolderDropFailure(name: "collision.txt", message: "File exists")])
    }

    func testFileManagerMoveKeepsCollisionsAndMovesOtherItems() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let collision = source.appendingPathComponent("same.txt")
        let movable = source.appendingPathComponent("move.txt")
        try Data("source".utf8).write(to: collision)
        try Data("destination".utf8).write(to: destination.appendingPathComponent("same.txt"))
        try Data("move".utf8).write(to: movable)

        let failures = FolderDropService.move([collision, movable], into: destination) { source, target in
            try FileManager.default.moveItem(at: source, to: target)
        }

        XCTAssertEqual(failures.map(\.name), ["same.txt"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: collision.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("move.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: movable.path))
    }
}
