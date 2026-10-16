import AppKit

struct DisplayOption: Identifiable {
    let id: UInt32
    let name: String

    static func preferredID(selectedID: UInt32?, availableIDs: [UInt32]) -> UInt32? {
        if let selectedID, availableIDs.contains(selectedID) { return selectedID }
        return availableIDs.first
    }

    @MainActor
    static var current: [DisplayOption] {
        NSScreen.screens.compactMap { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return nil }
            return DisplayOption(id: id, name: screen.localizedName)
        }
    }
}
