import Testing
@testable import ShelfUI

struct ColorFormatTests {
    struct Example: Sendable, CustomTestStringConvertible {
        let input: String
        let hex: String
        let rgb: String
        let hsl: String

        var testDescription: String {
            input
        }
    }

    @Test(arguments: [
        Example(input: "#FF9F0A", hex: "#FF9F0A", rgb: "rgb(255, 159, 10)", hsl: "hsl(36, 100%, 52%)"),
        Example(input: "ff3b30", hex: "#FF3B30", rgb: "rgb(255, 59, 48)", hsl: "hsl(3, 100%, 59%)"),
        Example(input: "#FFFFFF", hex: "#FFFFFF", rgb: "rgb(255, 255, 255)", hsl: "hsl(0, 0%, 100%)"),
        Example(input: " #0A84FF ", hex: "#0A84FF", rgb: "rgb(10, 132, 255)", hsl: "hsl(210, 100%, 52%)"),
        Example(input: "#FF00FF", hex: "#FF00FF", rgb: "rgb(255, 0, 255)", hsl: "hsl(300, 100%, 50%)"),
        Example(input: "rgb(26, 43, 60)", hex: "#1A2B3C", rgb: "rgb(26, 43, 60)", hsl: "hsl(210, 40%, 17%)")
    ])
    func `every format is derived from the copied value`(_ example: Example) throws {
        let color = try #require(ColorComponents(copiedText: example.input))

        #expect(color.formatted(.hex) == example.hex)
        #expect(color.formatted(.rgb) == example.rgb)
        #expect(color.formatted(.hsl) == example.hsl)
    }

    @Test(arguments: ["", "#FFF", "#GGGGGG", "#FF9F0A00", "rgb(256, 0, 0)"])
    func `invalid values have no formats`(_ input: String) {
        #expect(ColorComponents(copiedText: input) == nil)
    }
}
