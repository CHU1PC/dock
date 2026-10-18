import XCTest
@testable import DockStudio

final class DockSpringLoadingTests: XCTestCase {
    func testFolderOpensOnlyAfterHoverDelay() {
        XCTAssertNil(DockSpringLoading.action(for: .folder, elapsed: 0.99, enabled: true))
        XCTAssertEqual(DockSpringLoading.action(for: .folder, elapsed: 1, enabled: true), .openFolder)
        XCTAssertEqual(DockSpringLoading.action(for: .folder, elapsed: 1.5, enabled: true), .openFolder)
    }

    func testDisabledSpringLoadingAndOtherItemKindsDoNotOpen() {
        XCTAssertNil(DockSpringLoading.action(for: .folder, elapsed: 2, enabled: false))
        XCTAssertNil(DockSpringLoading.action(for: .application, elapsed: 2, enabled: true))
        XCTAssertNil(DockSpringLoading.action(for: .file, elapsed: 2, enabled: true))
    }

    func testCustomDelayIsApplied() {
        XCTAssertNil(DockSpringLoading.action(for: .folder, elapsed: 0.4, delay: 0.5, enabled: true))
        XCTAssertEqual(DockSpringLoading.action(for: .folder, elapsed: 0.5, delay: 0.5, enabled: true), .openFolder)
    }
}
