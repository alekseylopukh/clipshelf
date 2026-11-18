import AppKit
import CoreGraphics
import DesignSystem
import Testing

struct DesignTokensTests {
    @Test func `increase contrast thickens the selection ring by one point`() {
        let standard = DesignTokens.selectionRingWidth(for: .standard)
        #expect(DesignTokens.selectionRingWidth(for: .increased) == standard + 1)
    }

    @Test func `the shadow margin leaves room for the open rise`() {
        #expect(DesignTokens.shelfShadowMargin >= DesignTokens.shelfOpenOffset)
    }

    @Test func `the dark card fill is #2A2A2C`() throws {
        let components = try #require(sRGBComponents(of: DesignTokens.cardFill, in: .darkAqua))
        #expect(components == [0x2A, 0x2A, 0x2C, 0xFF])
    }

    @Test func `the light card fill is controlBackgroundColor`() throws {
        let fill = try #require(sRGBComponents(of: DesignTokens.cardFill, in: .aqua))
        let control = try #require(sRGBComponents(of: .controlBackgroundColor, in: .aqua))
        #expect(fill == control)
    }

    private func sRGBComponents(of color: NSColor, in appearanceName: NSAppearance.Name) -> [Int]? {
        guard let appearance = NSAppearance(named: appearanceName) else { return nil }
        var components: [Int]?
        appearance.performAsCurrentDrawingAppearance {
            guard let resolved = color.usingColorSpace(.sRGB) else { return }
            components = [
                resolved.redComponent,
                resolved.greenComponent,
                resolved.blueComponent,
                resolved.alphaComponent
            ]
            .map { Int(($0 * 255).rounded()) }
        }
        return components
    }
}
