import XCTest
@testable import DockStudio

final class ItemClickActionTests: XCTestCase {
    private func item(_ kind: DockItemKind, target: String?) -> DockItem {
        DockItem(name: "x", kind: kind, target: target)
    }

    private let policy = ItemClickPolicy()

    func testCommandAloneIsRevealClick() {
        XCTAssertTrue(ItemClickPolicy.isRevealClick([.command]))
        XCTAssertTrue(ItemClickPolicy.isRevealClick([.command, .capsLock]))
    }

    func testOtherModifierCombinationsAreNotRevealClick() {
        XCTAssertFalse(ItemClickPolicy.isRevealClick([]))
        XCTAssertFalse(ItemClickPolicy.isRevealClick([.option]))
        XCTAssertFalse(ItemClickPolicy.isRevealClick([.command, .option]))
        XCTAssertFalse(ItemClickPolicy.isRevealClick([.command, .shift]))
        XCTAssertFalse(ItemClickPolicy.isRevealClick([.command, .control]))
    }

    func testEventModifiersTakePrecedenceOverCurrentState() {
        XCTAssertEqual(ItemClickPolicy.clickModifiers(event: [.command], current: []), [.command])
        XCTAssertEqual(ItemClickPolicy.clickModifiers(event: [], current: [.command]), [])
        XCTAssertEqual(ItemClickPolicy.clickModifiers(event: nil, current: [.command]), [.command])
    }

    func testPlainClickOpens() {
        let app = item(.application, target: "file:///System/Applications/Calculator.app/")
        XCTAssertEqual(policy.action(for: app, revealRequested: false, availability: .available), .open)
        XCTAssertEqual(policy.action(for: app, revealRequested: false, availability: .missing), .open)
    }

    func testRevealForApplicationFolderAndFile() {
        for (kind, path) in [(DockItemKind.application, "/Applications/Calculator.app"),
                             (.folder, "/Users/me/Docs"), (.file, "/Users/me/a.txt")] {
            let target = URL(fileURLWithPath: path).absoluteString
            XCTAssertEqual(policy.action(for: item(kind, target: target), revealRequested: true, availability: .available),
                           .revealInFinder(URL(fileURLWithPath: path)))
        }
    }

    func testInaccessibleTargetIsStillRevealed() {
        let target = URL(fileURLWithPath: "/Users/me/secret").absoluteString
        XCTAssertEqual(policy.action(for: item(.folder, target: target), revealRequested: true, availability: .inaccessible),
                       .revealInFinder(URL(fileURLWithPath: "/Users/me/secret")))
    }

    func testMissingAndUnmountedStopWithMessageInsteadOfRevealing() {
        let target = URL(fileURLWithPath: "/Users/me/gone").absoluteString
        guard case .unavailable(let missing) = policy.action(for: item(.file, target: target), revealRequested: true, availability: .missing),
              case .unavailable(let unmounted) = policy.action(for: item(.file, target: target), revealRequested: true, availability: .volumeNotMounted)
        else { return XCTFail("expected unavailable") }
        XCTAssertNotEqual(missing, unmounted)
    }

    func testLinkAndUnsetTargetAreIgnored() {
        XCTAssertEqual(policy.action(for: item(.link, target: "https://example.com"), revealRequested: true, availability: .available), .ignore)
        XCTAssertEqual(policy.action(for: item(.file, target: nil), revealRequested: true, availability: .available), .ignore)
    }
}
