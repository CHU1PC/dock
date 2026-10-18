import Foundation

enum DockTemporaryMagnification {
    static func isMagnified(configured: Bool, modifiersHeld: Bool) -> Bool {
        modifiersHeld ? !configured : configured
    }
}
