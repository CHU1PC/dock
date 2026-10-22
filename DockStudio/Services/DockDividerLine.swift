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

    struct Insets: Equatable {
        var top: CGFloat
        var leading: CGFloat
        var bottom: CGFloat
        var trailing: CGFloat
    }

    static let axisPadding: CGFloat = 5

    static func insets(vertical: Bool) -> Insets {
        vertical
            ? Insets(top: axisPadding, leading: 0, bottom: axisPadding, trailing: 0)
            : Insets(top: 0, leading: axisPadding, bottom: 0, trailing: axisPadding)
    }
}
