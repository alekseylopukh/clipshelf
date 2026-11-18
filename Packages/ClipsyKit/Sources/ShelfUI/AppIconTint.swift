import CoreGraphics
import DesignSystem
import Foundation

struct AppIconTint: Equatable {
    var votes: [CardBandColor: Double]
    var darkShare: Double
    var lightShare: Double
}

extension AppIconTint {
    private static let minimumAlpha = 0.5
    private static let minimumChroma = 0.25
    private static let darkLuminance = 0.06
    private static let lightLuminance = 0.4

    init?(icon: CGImage) {
        let side = DesignTokens.appIconTintSampleSide
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let isDrawn = pixels.withUnsafeMutableBytes { buffer in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                      data: buffer.baseAddress,
                      width: side,
                      height: side,
                      bitsPerComponent: 8,
                      bytesPerRow: side * 4,
                      space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  )
            else { return false }
            context.interpolationQuality = .medium
            context.draw(icon, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard isDrawn else { return nil }

        var votes: [CardBandColor: Double] = [:]
        var opaqueCount = 0.0
        var darkCount = 0.0
        var lightCount = 0.0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > Self.minimumAlpha else { continue }
            opaqueCount += 1
            let red = Double(pixels[offset]) / 255 / alpha
            let green = Double(pixels[offset + 1]) / 255 / alpha
            let blue = Double(pixels[offset + 2]) / 255 / alpha
            let maximum = max(red, green, blue)
            let chroma = maximum - min(red, green, blue)
            if chroma >= Self.minimumChroma {
                let hue = Self.hueDegrees(red: red, green: green, blue: blue, maximum: maximum, chroma: chroma)
                votes[CardBandColor(hueDegrees: hue), default: 0] += chroma
            } else {
                let luminance = Self.luminance(red: red, green: green, blue: blue)
                if luminance < Self.darkLuminance {
                    darkCount += 1
                } else if luminance > Self.lightLuminance {
                    lightCount += 1
                }
            }
        }
        guard opaqueCount > 0 else { return nil }
        self.init(
            votes: votes.mapValues { $0 / opaqueCount },
            darkShare: darkCount / opaqueCount,
            lightShare: lightCount / opaqueCount
        )
    }

    private static func hueDegrees(
        red: Double,
        green: Double,
        blue: Double,
        maximum: Double,
        chroma: Double
    ) -> Double {
        let sector = switch maximum {
        case red: (green - blue) / chroma
        case green: (blue - red) / chroma + 2
        default: (red - green) / chroma + 4
        }
        return sector * 60
    }

    private static func luminance(red: Double, green: Double, blue: Double) -> Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
