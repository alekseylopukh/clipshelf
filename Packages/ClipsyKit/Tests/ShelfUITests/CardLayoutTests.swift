import CoreGraphics
import Testing
@testable import ShelfUI

struct CardLayoutTests {
    @Test(arguments: [
        (stripHeight: 116.0, expected: CardLayout.compact),
        (stripHeight: 181.9, expected: .compact),
        (stripHeight: 182.0, expected: .regular),
        (stripHeight: 256.0, expected: .regular)
    ])
    func `compact below threshold`(stripHeight: CGFloat, expected: CardLayout) {
        #expect(CardLayout(stripHeight: stripHeight) == expected)
    }
}
