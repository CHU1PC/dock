import SwiftUI

enum DockItemHitGeometry {
    static func hitFrame(in itemFrame: CGRect) -> CGRect {
        itemFrame
    }
}

struct DockItemHitShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(DockItemHitGeometry.hitFrame(in: rect))
    }
}
