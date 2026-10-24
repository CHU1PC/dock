import Foundation

enum DockVerticalFit {
    static let separatorLength = 30.0

    struct Content: Equatable {
        var fixedLength: Double
        var iconItemCount: Int
        var minimizedSlots: Int
        var magnificationReserve: Double
    }

    static func contentLength(_ content: Content, iconSize: Double, maximumSize: Double) -> Double {
        let (constant, perSize) = terms(content, maximumSize: maximumSize)
        return constant + perSize * iconSize
    }

    static func iconSize(_ content: Content, maximumSize: Double, minimumSize: Double,
                         availableLength: Double) -> Double {
        let (constant, perSize) = terms(content, maximumSize: maximumSize)
        return DockIconAutoShrink.size(maximumSize: maximumSize, minimumSize: minimumSize,
                                       availableLength: availableLength,
                                       fixedLength: constant, scalableLength: perSize)
    }

    private static func terms(_ content: Content, maximumSize: Double) -> (constant: Double, perSize: Double) {
        let paddedCount = Double(content.iconItemCount + 1)
        let constant = content.fixedLength + separatorLength
            + 10 * Double(content.minimizedSlots)
        let perSize = paddedCount * (1 + 10 / max(1, maximumSize))
            + Double(content.minimizedSlots) + content.magnificationReserve
        return (constant, perSize)
    }
}
