import Testing
@testable import DesignSystem

struct SwatchValueLabelTests {
    @Test(arguments: [0x000000, 0xFFFFFF, 0x797979, 0xFAB700, 0x0088FF])
    func `value text reads on the swatch`(hex: Int) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        let swatch = SwatchValueLabel.relativeLuminance(red: red, green: green, blue: blue)
        let text: Double = SwatchValueLabel.usesDarkText(red: red, green: green, blue: blue) ? 0 : 1
        let contrast = (max(swatch, text) + 0.05) / (min(swatch, text) + 0.05)
        #expect(contrast >= 4.5)
    }
}
