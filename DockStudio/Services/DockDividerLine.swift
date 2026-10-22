import CoreGraphics

enum DockDividerLine {
    static let thickness: CGFloat = 1

    static func length(iconSize: Double) -> CGFloat {
        CGFloat(max(1, iconSize.isFinite ? iconSize : 1))
    }

    static func size(iconSize: Double, vertical: Bool) -> CGSize {
        let length = length(iconSize: iconSize)
        return vertical ? CGSize(width: length, height: thickness) : CGSize(width: thickness, height: length)
    }
}
