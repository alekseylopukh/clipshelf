import Foundation
import Testing
@testable import ShelfUI

@MainActor
struct CardEntranceTests {
    @Test(arguments: [(0, 0.06), (1, 0.085), (7, 0.235), (8, 0.235), (40, 0.235)])
    func `cascade delay starts late and stops growing after the eighth card`(index: Int, delay: TimeInterval) {
        #expect(abs(CardEntrance.delay(at: index) - delay) < 1e-9)
    }
}
