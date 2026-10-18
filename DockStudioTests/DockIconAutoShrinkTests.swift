import XCTest
@testable import DockStudio

final class DockIconAutoShrinkTests: XCTestCase {
    func testKeepsMaximumSizeWhenAllIconsFit() {
        XCTAssertEqual(DockIconAutoShrink.size(maximumSize: 64, minimumSize: 16,
                                               availableLength: 500, fixedLength: 100,
                                               scalableLength: 4), 64)
    }

    func testShrinksToAvailableLengthWithoutExceedingMaximum() {
        XCTAssertEqual(DockIconAutoShrink.size(maximumSize: 64, minimumSize: 16,
                                               availableLength: 300, fixedLength: 100,
                                               scalableLength: 5), 40)
    }

    func testClampsToMinimumSizeWhenItemsCannotAllFit() {
        XCTAssertEqual(DockIconAutoShrink.size(maximumSize: 64, minimumSize: 16,
                                               availableLength: 150, fixedLength: 100,
                                               scalableLength: 10), 16)
    }

    func testDoesNotShrinkWhenThereAreNoScalableItems() {
        XCTAssertEqual(DockIconAutoShrink.size(maximumSize: 64, minimumSize: 16,
                                               availableLength: 100, fixedLength: 150,
                                               scalableLength: 0), 64)
    }
}
