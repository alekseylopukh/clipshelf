import CoreGraphics
import Testing
@testable import ShelfUI

struct AppIconTintTests {
    private static func image(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) throws -> CGImage {
        let side = 32
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: red, green: green, blue: blue, alpha: alpha)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        return try #require(context.makeImage())
    }

    @Test func `a solid red icon is red`() throws {
        let icon = try Self.image(red: 1, green: 0, blue: 0, alpha: 1)
        let tint = try #require(AppIconTint(icon: icon))
        #expect(min(tint.hue, 1 - tint.hue) < 0.01)
        #expect(tint.saturation > 0.95)
        #expect(tint.brightness > 0.95)
    }

    @Test func `a gray icon has no tint`() throws {
        let icon = try Self.image(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        #expect(AppIconTint(icon: icon) == nil)
    }

    @Test func `a transparent icon has no tint`() throws {
        let icon = try Self.image(red: 1, green: 0, blue: 0, alpha: 0)
        #expect(AppIconTint(icon: icon) == nil)
    }
}
