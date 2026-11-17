import Store
import Testing

struct CardColorTests {
    @Test(arguments: [
        ("#1A2B3C", CardColor(red: 0x1A, green: 0x2B, blue: 0x3C), CardColor.Format.hex),
        ("1a2b3c", CardColor(red: 0x1A, green: 0x2B, blue: 0x3C), .hex),
        ("#235442", CardColor(red: 0x23, green: 0x54, blue: 0x42), .hex),
        ("  #ffffff\n", CardColor(red: 0xFF, green: 0xFF, blue: 0xFF), .hex),
        ("rgb(26, 43, 60)", CardColor(red: 26, green: 43, blue: 60), .rgb),
        (" RGB(0,255 , 7) ", CardColor(red: 0, green: 255, blue: 7), .rgb)
    ])
    func `parses colors`(input: String, expected: CardColor, format: CardColor.Format) {
        #expect(CardColor(copiedText: input) == expected)
        #expect(CardColor.format(of: input) == format)
    }

    @Test(arguments: [
        "235442", "#FFF", "red", "color is #1A2B3C", "#1A2B3G", "#1A2B3C4D", "",
        "rgb(256, 0, 0)", "rgb(1, 2)", "rgb(1, 2, 3, 4)", "rgba(1, 2, 3)", "rgb(-1, 2, 3)", "rgb(1.5, 2, 3)",
        "rgb(, 2, 3)", "rgb(1 2 3)", "rgb(1, 2, 3) and more", "rgb(١, 2, 3)"
    ])
    func `rejects text that is not a color`(input: String) {
        #expect(CardColor(copiedText: input) == nil)
        #expect(CardColor.format(of: input) == nil)
    }

    @Test(arguments: CardColor.Format.allCases)
    func `color formats round trip`(format: CardColor.Format) {
        let colors = [
            CardColor(red: 0, green: 0, blue: 0),
            CardColor(red: 255, green: 255, blue: 255),
            CardColor(red: 0x1A, green: 0x2B, blue: 0x3C),
            CardColor(red: 9, green: 100, blue: 254)
        ]
        for color in colors {
            let text = color.text(in: format)
            #expect(CardColor(copiedText: text) == color)
            #expect(CardColor.format(of: text) == format)
        }
    }

    @Test func `formats are written the canonical way`() {
        let color = CardColor(red: 0x1A, green: 0x2B, blue: 0x3C)
        #expect(color.text(in: .hex) == "#1A2B3C")
        #expect(color.text(in: .rgb) == "rgb(26, 43, 60)")
    }
}
