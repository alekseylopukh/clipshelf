import AppKit
import DesignSystem
import SwiftUI

enum CardBandColor: CaseIterable, Hashable {
    case red
    case orange
    case amber
    case green
    case teal
    case blue
    case indigo
    case purple
    case pink
    case gray
    case graphite

    private static let minimumVote = 0.04
    private static let darkVotePenalty = 0.15

    init(hueDegrees: Double) {
        let hue = hueDegrees.truncatingRemainder(dividingBy: 360)
        switch hue < 0 ? hue + 360 : hue {
        case 10 ..< 39: self = .orange
        case 39 ..< 65: self = .amber
        case 65 ..< 160: self = .green
        case 160 ..< 190: self = .teal
        case 190 ..< 235: self = .blue
        case 235 ..< 270: self = .indigo
        case 270 ..< 318: self = .purple
        case 318 ..< 354: self = .pink
        default: self = .red
        }
    }

    init(tint: AppIconTint?) {
        guard let tint else {
            self = .gray
            return
        }
        let best = Self.allCases.max { tint.votes[$0, default: 0] < tint.votes[$1, default: 0] } ?? .gray
        if tint.votes[best, default: 0] >= Self.minimumVote + Self.darkVotePenalty * tint.darkShare {
            self = best
        } else {
            self = tint.darkShare > tint.lightShare ? .graphite : .gray
        }
    }

    func fill(in environment: EnvironmentValues) -> Color.Resolved {
        let fill = paletteFill(in: environment)
        guard environment.colorSchemeContrast == .increased,
              Self.whiteContrast(on: fill) < DesignTokens.cardHeaderIncreasedTextContrast
        else { return fill }
        let components = Self.hsb(fill)
        var brightness = components.brightness
        var legible = 0.0
        for _ in 0 ..< Self.searchSteps {
            let candidate = (legible + brightness) / 2
            let shade = components.color(brightness: candidate).resolve(in: environment)
            if Self.whiteContrast(on: shade) >= DesignTokens.cardHeaderIncreasedTextContrast {
                legible = candidate
            } else {
                brightness = candidate
            }
        }
        return components.color(brightness: legible).resolve(in: environment)
    }

    func isLight(in environment: EnvironmentValues) -> Bool {
        Self.whiteContrast(on: fill(in: environment)) < DesignTokens.cardBandLightContrast
    }

    static func whiteContrast(on fill: Color.Resolved) -> Double {
        func linear(_ component: Float) -> Double {
            let value = Double(component)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(fill.red) + 0.7152 * linear(fill.green) + 0.0722 * linear(fill.blue)
        return 1.05 / (luminance + 0.05)
    }

    private func paletteFill(in environment: EnvironmentValues) -> Color.Resolved {
        if let systemColor {
            var light = environment
            light.colorScheme = .light
            return Color(nsColor: systemColor).resolve(in: light)
        }
        let fill = switch self {
        case .graphite where environment.colorScheme == .dark: DesignTokens.cardBandGraphiteDark
        case .graphite: DesignTokens.cardBandGraphite
        default: DesignTokens.cardBandAmber
        }
        return fill.resolve(in: environment)
    }

    var systemColor: NSColor? {
        switch self {
        case .red: .systemRed
        case .orange: .systemOrange
        case .green: .systemGreen
        case .teal: .systemTeal
        case .blue: .systemBlue
        case .indigo: .systemIndigo
        case .purple: .systemPurple
        case .pink: .systemPink
        case .gray: .systemGray
        case .amber, .graphite: nil
        }
    }

    private static let searchSteps = 16

    private struct HSB {
        let hue: Double
        let saturation: Double
        let brightness: Double

        func color(brightness: Double) -> Color {
            Color(hue: hue, saturation: saturation, brightness: brightness)
        }
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
}
