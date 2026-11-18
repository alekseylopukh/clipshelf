import AppKit
import DesignSystem
import SwiftUI
import Testing
@testable import ShelfUI

@MainActor
struct CardBandColorTests {
    private static func environment(_ scheme: ColorScheme, increasedContrast: Bool = false) -> EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        if increasedContrast {
            environment._colorSchemeContrast = .increased
        }
        return environment
    }

    private static func distance(_ lhs: Color.Resolved, _ rhs: Color.Resolved) -> Float {
        max(abs(lhs.red - rhs.red), abs(lhs.green - rhs.green), abs(lhs.blue - rhs.blue))
    }

    @Test(arguments: CardBandColor.allCases, [ColorScheme.light, .dark])
    func `every band keeps its palette color`(color: CardBandColor, scheme: ColorScheme) throws {
        let environment = Self.environment(scheme)
        let expected: Color.Resolved
        if let systemColor = color.systemColor {
            let appearance = try #require(NSAppearance(named: .aqua))
            var light: NSColor?
            appearance.performAsCurrentDrawingAppearance {
                light = systemColor.usingColorSpace(.sRGB)
            }
            let components = try #require(light)
            expected = Color.Resolved(
                red: Float(components.redComponent),
                green: Float(components.greenComponent),
                blue: Float(components.blueComponent)
            )
        } else if color == .amber {
            expected = DesignTokens.cardBandAmber.resolve(in: environment)
        } else {
            let graphite = scheme == .dark ? DesignTokens.cardBandGraphiteDark : DesignTokens.cardBandGraphite
            expected = graphite.resolve(in: environment)
        }
        #expect(Self.distance(color.fill(in: environment), expected) < 0.005)
    }

    @Test(arguments: CardBandColor.allCases)
    func `the palette is the same in both schemes except graphite`(color: CardBandColor) {
        let light = color.fill(in: Self.environment(.light))
        let dark = color.fill(in: Self.environment(.dark))
        #expect((Self.distance(light, dark) < 0.001) == (color != .graphite))
    }

    @Test
    func `graphite is lighter in dark`() {
        let light = CardBandColor.graphite.fill(in: Self.environment(.light))
        let dark = CardBandColor.graphite.fill(in: Self.environment(.dark))
        #expect(CardBandColor.whiteContrast(on: dark) < CardBandColor.whiteContrast(on: light))
    }

    @Test(arguments: CardBandColor.allCases, [ColorScheme.light, .dark])
    func `increase contrast darkens every band for white text`(color: CardBandColor, scheme: ColorScheme) {
        let fill = color.fill(in: Self.environment(scheme, increasedContrast: true))
        #expect(CardBandColor.whiteContrast(on: fill) >= DesignTokens.cardHeaderIncreasedTextContrast - 0.01)
    }

    @Test(arguments: [
        (353.9, CardBandColor.pink),
        (354, .red),
        (9.9, .red),
        (10, .orange),
        (13, .orange),
        (38.9, .orange),
        (39, .amber),
        (64.9, .amber),
        (65, .green),
        (159.9, .green),
        (160, .teal),
        (189.9, .teal),
        (190, .blue),
        (234.9, .blue),
        (235, .indigo),
        (269.9, .indigo),
        (270, .purple),
        (317.9, .purple),
        (318, .pink)
    ])
    func `a hue falls into its window`(degrees: Double, expected: CardBandColor) {
        #expect(CardBandColor(hueDegrees: degrees) == expected)
    }

    @Test(arguments: CardBandColor.allCases.filter { $0 != .gray && $0 != .graphite })
    func `a hued band maps back to itself`(color: CardBandColor) throws {
        let fill = color.fill(in: Self.environment(.light))
        let red = Double(fill.red), green = Double(fill.green), blue = Double(fill.blue)
        let maximum = max(red, green, blue)
        let chroma = maximum - min(red, green, blue)
        try #require(chroma > 0)
        let sector = switch maximum {
        case red: (green - blue) / chroma
        case green: (blue - red) / chroma + 2
        default: (red - green) / chroma + 4
        }
        #expect(CardBandColor(hueDegrees: sector * 60) == color)
    }

    @Test
    func `no tint is gray`() {
        #expect(CardBandColor(tint: nil) == .gray)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func `only amber, orange, green and teal are light`(scheme: ColorScheme) {
        let light = CardBandColor.allCases.filter { $0.isLight(in: Self.environment(scheme)) }
        #expect(Set(light) == [.amber, .orange, .green, .teal])
    }
}
