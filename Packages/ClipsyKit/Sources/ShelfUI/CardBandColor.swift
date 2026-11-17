import AppKit
import DesignSystem
import SwiftUI

enum CardBandColor: CaseIterable {
    case red
    case orange
    case yellow
    case green
    case teal
    case blue
    case indigo
    case purple
    case pink
    case brown
    case gray

    private static let minimumSaturation = 0.25
    private static let brownHues = 0.03 ... 0.14
    private static let brownMaximumBrightness = 0.55

    init(tint: AppIconTint?) {
        guard let tint, tint.saturation >= Self.minimumSaturation else {
            self = .gray
            return
        }
        if Self.brownHues.contains(tint.hue), tint.brightness < Self.brownMaximumBrightness {
            self = .brown
            return
        }
        let hued = Self.allCases.compactMap { color in color.hue.map { (color, $0) } }
        let nearest = hued.min { lhs, rhs in
            Self.distance(lhs.1, tint.hue) < Self.distance(rhs.1, tint.hue)
        }
        self = nearest?.0 ?? .gray
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    var minimumWhiteContrast: Double {
        switch self {
        case .yellow: DesignTokens.cardHeaderYellowTextContrast
        case .orange, .green, .teal: DesignTokens.cardHeaderLightHueTextContrast
        case .red, .blue, .indigo, .purple, .pink, .brown, .gray: DesignTokens.cardHeaderTextContrast
        }
    }

    func legibleColor(in environment: EnvironmentValues, sheenOpacity: Double, minimumContrast: Double) -> Color {
        let resolved = color.resolve(in: environment)
        guard Self.whiteContrast(on: resolved, sheenOpacity: sheenOpacity) < minimumContrast else { return color }
        let components = Self.hsb(resolved)
        let hue = components.hue
        let saturation = components.saturation
        var brightness = components.brightness
        var legible = 0.0
        for _ in 0 ..< Self.searchSteps {
            let candidate = (legible + brightness) / 2
            let shade = Color(hue: hue, saturation: saturation, brightness: candidate).resolve(in: environment)
            if Self.whiteContrast(on: shade, sheenOpacity: sheenOpacity) >= minimumContrast {
                legible = candidate
            } else {
                brightness = candidate
            }
        }
        return Color(hue: hue, saturation: saturation, brightness: legible)
    }

    static func whiteContrast(on fill: Color.Resolved, sheenOpacity: Double) -> Double {
        func lightened(_ component: Float) -> Double {
            let mixed = Double(component) * (1 - sheenOpacity) + sheenOpacity
            return mixed <= 0.04045 ? mixed / 12.92 : pow((mixed + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * lightened(fill.red) + 0.7152 * lightened(fill.green) + 0.0722 * lightened(fill.blue)
        return 1.05 / (luminance + 0.05)
    }

    private static let searchSteps = 16

    private struct HSB {
        let hue: Double
        let saturation: Double
        let brightness: Double
    }

    private static func hsb(_ color: Color.Resolved) -> HSB {
        let red = Double(color.red), green = Double(color.green), blue = Double(color.blue)
        let maximum = max(red, green, blue)
        let delta = maximum - min(red, green, blue)
        guard maximum > 0, delta > 0 else { return HSB(hue: 0, saturation: 0, brightness: maximum) }
        let hue: Double = switch maximum {
        case red: (green - blue) / delta / 6
        case green: ((blue - red) / delta + 2) / 6
        default: ((red - green) / delta + 4) / 6
        }
        return HSB(hue: hue < 0 ? hue + 1 : hue, saturation: delta / maximum, brightness: maximum)
    }

    var nsColor: NSColor {
        switch self {
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .teal: .systemTeal
        case .blue: .systemBlue
        case .indigo: .systemIndigo
        case .purple: .systemPurple
        case .pink: .systemPink
        case .brown: .systemBrown
        case .gray: .systemGray
        }
    }

    var hue: Double? {
        switch self {
        case .red: 0.997
        case .orange: 0.078
        case .yellow: 0.133
        case .green: 0.375
        case .teal: 0.51
        case .blue: 0.578
        case .indigo: 0.679
        case .purple: 0.813
        case .pink: 0.968
        case .brown, .gray: nil
        }
    }

    private static func distance(_ lhs: Double, _ rhs: Double) -> Double {
        let delta = abs(lhs - rhs)
        return min(delta, 1 - delta)
    }
}
