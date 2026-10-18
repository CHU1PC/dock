import Foundation

enum DockIconAutoShrink {
    static func size(maximumSize: Double, minimumSize: Double, availableLength: Double,
                     fixedLength: Double, scalableLength: Double) -> Double {
        let maximum = maximumSize.isFinite ? max(0, maximumSize) : 0
        let minimum = minimumSize.isFinite ? min(maximum, max(0, minimumSize)) : 0
        guard availableLength.isFinite, fixedLength.isFinite, scalableLength.isFinite,
              scalableLength > 0 else { return maximum }

        let fittingSize = (availableLength - fixedLength) / scalableLength
        guard fittingSize < maximum else { return maximum }
        return max(minimum, min(maximum, fittingSize))
    }
}
