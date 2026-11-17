import AppKit
import DesignSystem
import SwiftUI
import Testing
@testable import ShelfUI

@MainActor
struct CardBandColorTests {
    @Test(arguments: CardBandColor.allCases, [ColorScheme.light, .dark])
    func `white text keeps its contrast on every legible band`(color: CardBandColor, scheme: ColorScheme) {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let sheen = DesignTokens.cardHeaderSheenOpacity / 2
        for minimum in [color.minimumWhiteContrast, DesignTokens.cardHeaderIncreasedTextContrast] {
            let fill = color.legibleColor(in: environment, sheenOpacity: sheen, minimumContrast: minimum)
            let contrast = CardBandColor.whiteContrast(on: fill.resolve(in: environment), sheenOpacity: sheen)
            #expect(contrast >= minimum - 0.01)
        }
    }

    @Test(arguments: [CardBandColor.yellow, .orange, .green, .teal], [ColorScheme.light, .dark])
    func `light hues stay close to their system color`(color: CardBandColor, scheme: ColorScheme) {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let system = color.color.resolve(in: environment)
        let fill = color.legibleColor(
            in: environment,
            sheenOpacity: DesignTokens.cardHeaderSheenOpacity / 2,
            minimumContrast: color.minimumWhiteContrast
        ).resolve(in: environment)
        #expect(max(system.red, system.green, system.blue) - max(fill.red, fill.green, fill.blue) < 0.25)
    }

    @Test(arguments: [
        (AppIconTint(hue: 0.58, saturation: 0.9, brightness: 0.9), CardBandColor.blue),
        (AppIconTint(hue: 0.99, saturation: 0.9, brightness: 0.9), .red),
        (AppIconTint(hue: 0.005, saturation: 0.9, brightness: 0.9), .red),
        (AppIconTint(hue: 0.975, saturation: 0.9, brightness: 0.9), .pink),
        (AppIconTint(hue: 0.13, saturation: 0.9, brightness: 0.9), .yellow),
        (AppIconTint(hue: 0.08, saturation: 0.9, brightness: 0.9), .orange),
        (AppIconTint(hue: 0.08, saturation: 0.9, brightness: 0.4), .brown),
        (AppIconTint(hue: 0.37, saturation: 0.9, brightness: 0.9), .green),
        (AppIconTint(hue: 0.5, saturation: 0.9, brightness: 0.9), .teal),
        (AppIconTint(hue: 0.68, saturation: 0.9, brightness: 0.9), .indigo),
        (AppIconTint(hue: 0.8, saturation: 0.9, brightness: 0.9), .purple),
        (AppIconTint(hue: 0.58, saturation: 0.1, brightness: 0.9), .gray)
    ])
    func `a tint snaps to the nearest system color`(tint: AppIconTint, expected: CardBandColor) {
        #expect(CardBandColor(tint: tint) == expected)
    }

    @Test
    func `gray icons get a gray band`() {
        #expect(CardBandColor(tint: nil) == .gray)
    }

    @Test(arguments: CardBandColor.allCases)
    func `the hue table matches the light system colors`(color: CardBandColor) throws {
        guard let hue = color.hue else { return }
        let appearance = try #require(NSAppearance(named: .aqua))
        var systemHue = -1.0
        appearance.performAsCurrentDrawingAppearance {
            systemHue = color.nsColor.usingColorSpace(.sRGB).map { Double($0.hueComponent) } ?? -1
        }
        #expect(abs(systemHue - hue) < 0.005)
    }
}
