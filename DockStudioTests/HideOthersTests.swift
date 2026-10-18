import XCTest
@testable import DockStudio

private final class FakeApp: OtherApplicationsHideable {
    let bundleIdentifier: String?
    let processIdentifier: pid_t
    let isRegularApplication: Bool
    var isTerminated = false
    var isHidden: Bool
    let activates: Bool
    private(set) var activateCalls = 0
    private(set) var hideCalls = 0
    init(_ id: String, pid: pid_t, regular: Bool = true, hidden: Bool = false, activates: Bool = true) {
        bundleIdentifier = id; processIdentifier = pid; isRegularApplication = regular
        isHidden = hidden; self.activates = activates
    }
    func activateApplication() -> Bool { activateCalls += 1; return activates }
    func hideApplication() -> Bool { hideCalls += 1; return true }
}

final class HideOthersTests: XCTestCase {
    private func hider(_ apps: [FakeApp]) -> OtherApplicationsHider {
        OtherApplicationsHider(runningApplications: { apps }, ownProcessIdentifier: 1)
    }

    private func app(_ id: String) -> DockItem {
        DockItem(name: id, kind: .application, target: nil, bundleIdentifier: id)
    }

    func testCommandOptionIsHideOthersOnly() {
        XCTAssertTrue(ItemClickPolicy.isHideOthersClick([.command, .option]))
        XCTAssertTrue(ItemClickPolicy.isHideOthersClick([.command, .option, .capsLock]))
        XCTAssertFalse(ItemClickPolicy.isHideOthersClick([]))
        XCTAssertFalse(ItemClickPolicy.isHideOthersClick([.command]))
        XCTAssertFalse(ItemClickPolicy.isHideOthersClick([.option]))
        XCTAssertFalse(ItemClickPolicy.isHideOthersClick([.command, .option, .shift]))
        XCTAssertFalse(ItemClickPolicy.isHideOthersClick([.command, .option, .control]))
    }

    func testModifierCombinationsDoNotOverlap() {
        XCTAssertTrue(ItemClickPolicy.isRevealClick([.command]))
        XCTAssertFalse(ItemClickPolicy.isHideOthersClick([.command]))
        XCTAssertFalse(ItemClickPolicy.isRevealClick([.command, .option]))
        XCTAssertTrue(ItemClickPolicy.isHideOthersClick([.command, .option]))
        XCTAssertFalse(ItemClickPolicy.isRevealClick([.option]))
        XCTAssertFalse(ItemClickPolicy.isHideOthersClick([.option]))
    }

    func testMenuListsHideOthersOnlyWhenAllowed() {
        XCTAssertEqual(DockItemMenu.kinds(hasFileURL: true, visibility: .visible, canHideOthers: true, canQuit: true, isPinned: true),
                       [.open, .reveal, .hide, .hideOthers, .quit, .forceQuit, .remove])
        XCTAssertEqual(DockItemMenu.kinds(hasFileURL: true, canQuit: false, isPinned: false), [.open, .reveal, .keep])
        XCTAssertEqual(DockItemMenu.Kind.hideOthers.title, "ほかを隠す")
    }

    func testApplicationMenuIncludesSpacesAssignmentGuide() {
        XCTAssertEqual(DockItemMenu.kinds(hasFileURL: true, canQuit: false, isPinned: true, isApplication: true),
                       [.open, .reveal, .openLoginItemsSettings, .spacesAssignmentGuide, .remove])
        XCTAssertFalse(DockItemMenu.kinds(hasFileURL: true, canQuit: false, isPinned: true).contains(.spacesAssignmentGuide))
        XCTAssertEqual(DockItemMenu.Kind.spacesAssignmentGuide.title, "Spaces への割り当て方法")
        XCTAssertTrue(DockItemMenu.spacesAssignmentGuideMessage.contains("Control キーを押しながらクリック"))
        XCTAssertTrue(DockItemMenu.spacesAssignmentGuideMessage.contains("「オプション」>「割り当て先」"))
        XCTAssertTrue(DockItemMenu.spacesAssignmentGuideMessage.contains("Spaces が2つ以上"))
        XCTAssertTrue(DockItemMenu.spacesAssignmentGuideMessage.contains("標準 Dock にアプリアイコンがない場合"))
    }

    func testLoginItemsSettingsIsOnlyOfferedForApplicationItems() {
        let applicationKinds = DockItemMenu.kinds(hasFileURL: true, canQuit: false, isPinned: false,
                                                  isApplication: true)
         XCTAssertEqual(applicationKinds, [.open, .reveal, .openLoginItemsSettings, .spacesAssignmentGuide, .keep])
        XCTAssertEqual(DockItemMenu.Kind.openLoginItemsSettings.title, "システム設定のログイン項目を開く")
        XCTAssertFalse(DockItemMenu.Kind.openLoginItemsSettings.isAccessibilityAction)

        let fileKinds = DockItemMenu.kinds(hasFileURL: true, canQuit: false, isPinned: false)
        XCTAssertFalse(fileKinds.contains(.openLoginItemsSettings))
    }

    func testFolderMenuOffersOnlyTheAlternateDisplayStyle() {
        XCTAssertEqual(DockItemMenu.kinds(hasFileURL: true, canQuit: false, isPinned: false,
                                          folderDisplayStyle: .folder),
                       [.open, .reveal, .setStackIcon, .keep])
        XCTAssertEqual(DockItemMenu.kinds(hasFileURL: true, canQuit: false, isPinned: false,
                                          folderDisplayStyle: .stack),
                       [.open, .reveal, .setFolderIcon, .keep])
    }

    func testTargetIsActivatedAndOthersAreHidden() {
        let target = FakeApp("com.example.target", pid: 10)
        let other = FakeApp("com.example.other", pid: 11)
        XCTAssertEqual(hider([target, other]).hideOthers(of: app("com.example.target")), .hidOthers(1))
        XCTAssertEqual(target.activateCalls, 1)
        XCTAssertEqual(target.hideCalls, 0)
        XCTAssertEqual(other.hideCalls, 1)
    }

    func testSelfBackgroundHiddenAndTerminatedAreLeftAlone() {
        let target = FakeApp("com.example.target", pid: 10)
        let own = FakeApp("com.example.self", pid: 1)
        let background = FakeApp("com.example.agent", pid: 12, regular: false)
        let alreadyHidden = FakeApp("com.example.hidden", pid: 13, hidden: true)
        let gone = FakeApp("com.example.gone", pid: 14)
        gone.isTerminated = true
        _ = hider([target, own, background, alreadyHidden, gone]).hideOthers(of: app("com.example.target"))
        XCTAssertEqual(own.hideCalls + background.hideCalls + alreadyHidden.hideCalls + gone.hideCalls, 0)
    }

    func testNotRunningTargetHidesNothing() {
        let other = FakeApp("com.example.other", pid: 11)
        XCTAssertEqual(hider([other]).hideOthers(of: app("com.example.target")), .notRunning)
        XCTAssertEqual(other.hideCalls, 0)
    }

    func testActivationFailureHidesNothing() {
        let target = FakeApp("com.example.target", pid: 10, activates: false)
        let other = FakeApp("com.example.other", pid: 11)
        XCTAssertEqual(hider([target, other]).hideOthers(of: app("com.example.target")), .rejected)
        XCTAssertEqual(other.hideCalls, 0)
    }

    func testNonApplicationItemIsNotHideable() {
        let other = FakeApp("com.example.other", pid: 11)
        let folder = DockItem(name: "f", kind: .folder, target: "/tmp")
        XCTAssertEqual(hider([other]).hideOthers(of: folder), .notHideable)
        XCTAssertEqual(other.hideCalls, 0)
    }
}
