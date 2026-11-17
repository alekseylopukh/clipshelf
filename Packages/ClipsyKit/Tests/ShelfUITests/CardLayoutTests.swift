import CoreGraphics
import Testing
@testable import ShelfUI

struct CardLayoutTests {
    @Test(arguments: [
        (stripHeight: 154.0, expected: CardLayout.compact),
        (stripHeight: 173.9, expected: .compact),
        (stripHeight: 174.0, expected: .regular),
        (stripHeight: 294.0, expected: .regular)
    ])
    func `compact below threshold`(stripHeight: CGFloat, expected: CardLayout) {
        #expect(CardLayout(stripHeight: stripHeight) == expected)
    }
}
