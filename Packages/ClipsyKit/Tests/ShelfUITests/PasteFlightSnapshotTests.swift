import CoreGraphics
import Foundation
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

    @Test func `the strip rect is the union of the card frames`() {
        let rect = PasteFlightSnapshot.stripRect(
            ofCardFrames: [
                CGRect(x: 48, y: 108, width: 220, height: 220),
                CGRect(x: 284, y: 108, width: 220, height: 220)
            ],
            in: bounds
        )

        #expect(rect == CGRect(x: 48, y: 36, width: 456, height: 220))
    }

    @Test func `no card frames give an empty strip rect`() {
        let rect = PasteFlightSnapshot.stripRect(ofCardFrames: [], in: bounds)

        #expect(rect.isEmpty)
    }

    @Test func `crops a card from the strip bitmap with a top-left origin`() {
        let rect = PasteFlightSnapshot.cropRect(
            of: CGRect(x: 284, y: 36, width: 220, height: 222),
            in: CGRect(x: 48, y: 30, width: 456, height: 230),
            scale: 2
        )

        #expect(rect == CGRect(x: 472, y: 4, width: 440, height: 444))
    }

    @Test(arguments: [
        (CGFloat(0), 0.28),
        (100, 0.28),
        (900, 0.44),
        (5000, 0.44),
    ])
    func `the flight lasts longer for a longer distance`(distance: CGFloat, duration: TimeInterval) {
        #expect(abs(PasteFlightSnapshot.flightDuration(distance: distance) - duration) < 1e-9)
    }
}
