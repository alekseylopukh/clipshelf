import Foundation

struct ColorComponents: Equatable {
    let red: Int
    let green: Int
    let blue: Int

    init?(hex value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.hasPrefix("#") ? trimmed.dropFirst() : Substring(trimmed)
        guard digits.count == 6, let rgb = UInt32(digits, radix: 16) else { return nil }
        red = Int(rgb >> 16 & 0xFF)
        green = Int(rgb >> 8 & 0xFF)
        blue = Int(rgb & 0xFF)
    }

    func formatted(_ format: ColorFormat) -> String {
        switch format {
        case .hex:
            String(format: "#%02X%02X%02X", red, green, blue)
        case .rgb:
            "rgb(\(red), \(green), \(blue))"
        case .hsl:
            hsl
        }
    }

    private var hsl: String {
        let channels = [red, green, blue].map { Double($0) / 255 }
        let (high, low) = (channels.max() ?? 0, channels.min() ?? 0)
        let delta = high - low
        let lightness = (high + low) / 2
        let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
        let hue: Double = switch high {
        case _ where delta == 0: 0
        case channels[0]: 60 * ((channels[1] - channels[2]) / delta).truncatingRemainder(dividingBy: 6)
        case channels[1]: 60 * ((channels[2] - channels[0]) / delta + 2)
        default: 60 * ((channels[0] - channels[1]) / delta + 4)
        }
        let degrees = Int(((hue + 360).truncatingRemainder(dividingBy: 360)).rounded())
        return "hsl(\(degrees % 360), \(Int((saturation * 100).rounded()))%, \(Int((lightness * 100).rounded()))%)"
    }
}
