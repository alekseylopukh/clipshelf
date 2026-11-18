import Foundation
import Testing
@testable import ShelfUI

@MainActor
struct CardEntranceTests {
    @Test(arguments: [(0, 0.08), (1, 0.11), (7, 0.29), (8, 0.29), (40, 0.29)])
    func `cascade delay starts late and stops growing after the eighth card`(index: Int, delay: TimeInterval) {
        #expect(abs(CardEntrance.delay(at: index) - delay) < 1e-9)
    }
}
