import AppKit
import Foundation
import SwiftUI

struct DockAppearance: Codable, Equatable {
    enum Background: String, Codable, CaseIterable, Identifiable {
        case appleDock, system, color, image, transparent
        var id: String { rawValue }
        var title: String {
            switch self {
            case .appleDock: "Apple Dock"
            case .system: "システム素材"
            case .color: "単色"
            case .image: "画像"
            case .transparent: "完全透明"
            }
        }
    }

    enum IconStyle: String, Codable, CaseIterable, Identifiable {
        case original, monochrome, glass
        var id: String { rawValue }
        var title: String {
            switch self {
            case .original: "通常"
            case .monochrome: "白黒"
            case .glass: "ガラス調"
            }
        }
    }

    enum ColorMode: String, Codable, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: "システムに合わせる"
            case .light: "ライト"
            case .dark: "ダーク"
            }
        }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
        var nsAppearance: NSAppearance? {
            switch self {
            case .system: nil
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            }
        }
    }

    static let cornerRadius = 22.0

    var background: Background = .system
    var color: UInt32 = 0x303842
    var opacity = 0.55
    var blur = true
    var image: String?
    var iconStyle: IconStyle = .original
    var colorMode: ColorMode = .system
    var magnification = true
    var magnificationScale = 1.45
    var runningIndicators = true
    var reduceMotion = false

    init() {}

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case background, color, opacity, blur, image, iconStyle, colorMode
        case magnification, magnificationScale, runningIndicators, reduceMotion
    }

    init(from decoder: Decoder) throws {
        let keys = try decoder.container(keyedBy: AppearanceKey.self)
        let known = Set(CodingKeys.allCases.map(\.rawValue))
        guard keys.allKeys.allSatisfy({ known.contains($0.stringValue) }) else {
            throw DockDataError.invalidData("Unknown appearance settings. Open this configuration with a newer version.")
        }
        let values = try decoder.container(keyedBy: CodingKeys.self)
        background = try values.decodeIfPresent(Background.self, forKey: .background) ?? .system
        color = try values.decodeIfPresent(UInt32.self, forKey: .color) ?? 0x303842
        opacity = try values.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.55
        blur = try values.decodeIfPresent(Bool.self, forKey: .blur) ?? true
        image = try values.decodeIfPresent(String.self, forKey: .image)
        iconStyle = try values.decodeIfPresent(IconStyle.self, forKey: .iconStyle) ?? .original
        colorMode = try values.decodeIfPresent(ColorMode.self, forKey: .colorMode) ?? .system
        magnification = try values.decodeIfPresent(Bool.self, forKey: .magnification) ?? true
        magnificationScale = try values.decodeIfPresent(Double.self, forKey: .magnificationScale) ?? 1.45
        runningIndicators = try values.decodeIfPresent(Bool.self, forKey: .runningIndicators) ?? true
        reduceMotion = try values.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? false
        try validate()
    }

    func validate() throws {
        guard opacity.isFinite, (0...1).contains(opacity), color <= 0xffffff,
              magnificationScale.isFinite, (1...2).contains(magnificationScale) else {
            throw DockDataError.invalidData("Invalid appearance values.")
        }
    }

    static func scale(index: Int, hovered: Int?, maximum: Double) -> Double {
        guard let hovered else { return 1 }
        switch abs(index - hovered) {
        case 0: return maximum
        case 1: return 1 + (maximum - 1) * 0.45
        case 2: return 1 + (maximum - 1) * 0.12
        default: return 1
        }
    }
}

private struct AppearanceKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
