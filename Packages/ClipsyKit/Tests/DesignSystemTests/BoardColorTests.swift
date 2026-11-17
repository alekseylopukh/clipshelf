import DesignSystem
import Testing

struct BoardColorTests {
    @Test(arguments: [
        (BoardColor.red, "red"),
        (.orange, "orange"),
        (.yellow, "yellow"),
        (.green, "green"),
        (.blue, "blue"),
        (.purple, "purple"),
        (.gray, "gray")
    ])
    func `board color round trips stored name`(color: BoardColor, storedName: String) {
        #expect(color.rawValue == storedName)
        #expect(BoardColor(rawValue: storedName) == color)
    }

    @Test func `palette has seven colors`() {
        #expect(BoardColor.allCases.count == 7)
    }

    @Test(arguments: ["pink", "Red", ""])
    func `unknown stored name has no board color`(storedName: String) {
        #expect(BoardColor(rawValue: storedName) == nil)
    }
}
