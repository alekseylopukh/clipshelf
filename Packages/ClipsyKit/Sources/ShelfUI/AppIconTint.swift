import CoreGraphics
import DesignSystem
import Foundation

struct AppIconTint: Equatable {
    let hue: Double
    let saturation: Double
    let brightness: Double
}

extension AppIconTint {
    private static let hueBins = 12
    private static let minimumAlpha = 0.5
    private static let minimumShare = 0.06

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

        var bins = [Bin](repeating: Bin(), count: Self.hueBins)
        var opaqueCount = 0.0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > Self.minimumAlpha else { continue }
            opaqueCount += 1
            let red = Double(pixels[offset]) / 255 / alpha
            let green = Double(pixels[offset + 1]) / 255 / alpha
            let blue = Double(pixels[offset + 2]) / 255 / alpha
            let maximum = max(red, green, blue)
            let delta = maximum - min(red, green, blue)
            guard maximum > 0, delta > 0 else { continue }
            let saturation = delta / maximum
            let hue: Double = switch maximum {
            case red: (green - blue) / delta / 6
            case green: ((blue - red) / delta + 2) / 6
            default: ((red - green) / delta + 4) / 6
            }
            let wrapped = hue < 0 ? hue + 1 : hue
            let weight = saturation * maximum
            let index = min(Int(wrapped * Double(Self.hueBins)), Self.hueBins - 1)
            bins[index].add(hue: wrapped, saturation: saturation, brightness: maximum, weight: weight)
        }
        guard opaqueCount > 0,
              let best = bins.max(by: { $0.weight < $1.weight }),
              best.weight / opaqueCount >= Self.minimumShare
        else { return nil }
        let angle = atan2(best.hueY, best.hueX) / (2 * .pi)
        self.init(
            hue: angle < 0 ? angle + 1 : angle,
            saturation: best.saturation / best.weight,
            brightness: best.brightness / best.weight
        )
    }

    private struct Bin {
        var weight = 0.0
        var hueX = 0.0
        var hueY = 0.0
        var saturation = 0.0
        var brightness = 0.0

        mutating func add(hue: Double, saturation: Double, brightness: Double, weight: Double) {
            self.weight += weight
            hueX += cos(hue * 2 * .pi) * weight
            hueY += sin(hue * 2 * .pi) * weight
            self.saturation += saturation * weight
            self.brightness += brightness * weight
        }
    }
}
