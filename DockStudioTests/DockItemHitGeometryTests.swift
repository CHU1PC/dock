import AppKit
import XCTest
@testable import DockStudio

final class DockItemHitGeometryTests: XCTestCase {
    func testHitFrameEqualsItemFrameAcrossSupportedIconSizes() {
        for iconSize in 16...128 {
            let itemFrame = CGRect(x: 20, y: 30, width: CGFloat(iconSize + 10), height: CGFloat(iconSize + 14))

            XCTAssertEqual(DockItemHitGeometry.hitFrame(in: itemFrame), itemFrame,
                           "icon size \(iconSize)")
        }
    }
}
