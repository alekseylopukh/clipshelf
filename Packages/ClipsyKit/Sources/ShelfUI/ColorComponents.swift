import Foundation
import Store

struct ColorComponents: Equatable {
    let red: Int
    let green: Int
    let blue: Int

    init?(copiedText: String) {
        guard let color = CardColor(copiedText: copiedText) else { return nil }
        red = Int(color.red)
        green = Int(color.green)
        blue = Int(color.blue)
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
