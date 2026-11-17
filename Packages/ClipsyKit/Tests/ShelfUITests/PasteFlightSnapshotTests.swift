import CoreGraphics
import Testing
@testable import ShelfUI

struct PasteFlightSnapshotTests {
    private let bounds = CGRect(x: 0, y: 0, width: 1500, height: 364)

    @Test func `flips a top-down card frame into the content view`() {
        let rect = PasteFlightSnapshot.contentRect(
            ofCardFrame: CGRect(x: 48, y: 108, width: 220, height: 220),
            in: bounds
        )

        #expect(rect == CGRect(x: 48, y: 36, width: 220, height: 220))
    }

    @Test func `clips a card that is partly outside the content view`() {
        let rect = PasteFlightSnapshot.contentRect(
            ofCardFrame: CGRect(x: -100, y: 108, width: 220, height: 220),
            in: bounds
        )

        #expect(rect == CGRect(x: 0, y: 36, width: 120, height: 220))
    }

    @Test func `a card outside the content view gives an empty rect`() {
        let rect = PasteFlightSnapshot.contentRect(
            ofCardFrame: CGRect(x: 1600, y: 108, width: 220, height: 220),
            in: bounds
        )

        #expect(rect.isEmpty)
    }
}
