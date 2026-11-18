import Foundation
import Testing
@testable import ShelfUI

@MainActor
struct CardEntranceTests {
    @Test(arguments: [(0, 0.0), (1, 0.014), (7, 0.098), (8, 0.098), (40, 0.098)])
    func `cascade delay stops growing after the eighth card`(index: Int, delay: TimeInterval) {
        #expect(abs(CardEntrance.delay(at: index) - delay) < 1e-9)
    }
}
