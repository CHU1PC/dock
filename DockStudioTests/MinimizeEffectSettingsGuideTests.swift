import XCTest
@testable import DockStudio

final class MinimizeEffectSettingsGuideTests: XCTestCase {
    func testInstructionsPointToSystemSettingNamesForSupportedVersions() {
        let instructions = MinimizeEffectSettingsGuide.instructions

        XCTAssertTrue(instructions.contains("システム設定 > デスクトップとDock > Dock"))
        XCTAssertTrue(instructions.contains("macOS 15では「ウインドウをしまうときのエフェクト」"))
        XCTAssertTrue(instructions.contains("macOS 26では「ウインドウをしまうときのアニメーション」"))
        XCTAssertTrue(instructions.contains("Dock Studioからこの効果は変更できません。"))
    }
}
