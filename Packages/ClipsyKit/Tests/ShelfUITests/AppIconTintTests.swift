import CoreGraphics
import Foundation
import Testing
@testable import ShelfUI

struct AppIconTintTests {
    struct Pixel: Sendable, CustomTestStringConvertible {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        var alpha: UInt8 = 255

        var testDescription: String {
            "#\([red, green, blue, alpha].map { String(format: "%02X", $0) }.joined())"
        }

        static let black = Pixel(red: 0, green: 0, blue: 0)
        static let white = Pixel(red: 255, green: 255, blue: 255)
    }

    private static func image(_ base: Pixel, accent: Pixel? = nil, share: Double = 0) throws -> CGImage {
        let side = 32
        let accentCount = Int((Double(side * side) * share).rounded())
        var bytes = [UInt8]()
        for index in 0 ..< side * side {
            let pixel = index < accentCount ? accent ?? base : base
            let alpha = Double(pixel.alpha) / 255
            bytes += [pixel.red, pixel.green, pixel.blue].map { UInt8((Double($0) * alpha).rounded()) } + [pixel.alpha]
        }
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        return try #require(CGImage(
            width: side,
            height: side,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: side * 4,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
    }

    @Test(arguments: [
        (Pixel(red: 255, green: 0, blue: 0), CardBandColor.red),
        (Pixel(red: 128, green: 128, blue: 128), .gray),
        (Pixel(red: 0x1C, green: 0x1C, blue: 0x1E), .graphite),
        (Pixel.white, .gray),
        (Pixel(red: 0xD9, green: 0x77, blue: 0x57), .orange),
        (Pixel(red: 0xFF, green: 0xCC, blue: 0x00), .amber)
    ])
    func `a solid icon picks its band`(pixel: Pixel, expected: CardBandColor) throws {
        let tint = try #require(AppIconTint(icon: Self.image(pixel)))
        #expect(CardBandColor(tint: tint) == expected)
    }

    @Test func `a transparent icon has no tint`() throws {
        let icon = try Self.image(Pixel(red: 255, green: 0, blue: 0, alpha: 0))
        #expect(AppIconTint(icon: icon) == nil)
    }

    @Test(arguments: [
        (Pixel.black, Pixel(red: 0, green: 0, blue: 255), 0.08, CardBandColor.graphite),
        (Pixel.black, Pixel(red: 0, green: 255, blue: 0), 0.25, .green),
        (Pixel.white, Pixel(red: 255, green: 255, blue: 0), 0.2, .amber),
        (Pixel.white, Pixel(red: 255, green: 0, blue: 0), 0.02, .gray)
    ])
    func `a two-color icon weighs its accent`(
        base: Pixel,
        accent: Pixel,
        share: Double,
        expected: CardBandColor
    ) throws {
        let tint = try #require(AppIconTint(icon: Self.image(base, accent: accent, share: share)))
        #expect(CardBandColor(tint: tint) == expected)
    }
}
