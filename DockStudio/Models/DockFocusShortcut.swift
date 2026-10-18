import Carbon.HIToolbox

enum DockFocusShortcut: String, Codable, CaseIterable, Identifiable {
    case controlOptionCommandD
    case controlOptionCommandK
    case controlOptionCommandM
    case controlOptionCommandF

    var id: String { rawValue }

    var title: String {
        switch self {
        case .controlOptionCommandD: "⌃⌥⌘D"
        case .controlOptionCommandK: "⌃⌥⌘K"
        case .controlOptionCommandM: "⌃⌥⌘M"
        case .controlOptionCommandF: "⌃⌥⌘F"
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .controlOptionCommandD: UInt32(kVK_ANSI_D)
        case .controlOptionCommandK: UInt32(kVK_ANSI_K)
        case .controlOptionCommandM: UInt32(kVK_ANSI_M)
        case .controlOptionCommandF: UInt32(kVK_ANSI_F)
        }
    }

    var carbonModifiers: UInt32 { UInt32(controlKey | optionKey | cmdKey) }
}
