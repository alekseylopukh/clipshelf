import Capture
import Testing

struct HexColorTests {
    @Test(arguments: [
        ("#1A2B3C", HexColor(red: 0x1A, green: 0x2B, blue: 0x3C)),
        ("1a2b3c", HexColor(red: 0x1A, green: 0x2B, blue: 0x3C)),
        ("#235442", HexColor(red: 0x23, green: 0x54, blue: 0x42)),
        ("  #ffffff\n", HexColor(red: 0xFF, green: 0xFF, blue: 0xFF))
    ])
    func `parses hex colors`(input: String, expected: HexColor) {
        #expect(HexColor(copiedText: input) == expected)
    }

    @Test(arguments: ["235442", "#FFF", "rgb(1, 2, 3)", "red", "color is #1A2B3C", "#1A2B3G", "#1A2B3C4D", ""])
    func `rejects text that is not a hex color`(input: String) {
        #expect(HexColor(copiedText: input) == nil)
    }
}
