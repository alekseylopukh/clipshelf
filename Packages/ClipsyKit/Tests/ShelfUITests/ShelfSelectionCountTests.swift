import Foundation
import Store
import Testing
@testable import ShelfUI

@MainActor
final class ShelfSelectionCountTests {
    private let suiteName = "ShelfSelectionCountTests-\(UUID().uuidString)"
    private let model: ShelfModel

    init() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        model = ShelfModel(
            defaults: defaults,
            observe: { _ in AsyncThrowingStream { $0.finish() } },
            observeBoards: { AsyncThrowingStream { $0.finish() } }
        )
    }

    private func receive(_ ids: [Int64]) {
        model.receive(ids.map { CardSummary(
            id: $0,
            kind: .text,
            createdAt: Date(timeIntervalSince1970: TimeInterval($0))
        ) })
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test func `no count without a selection`() {
        receive([])
        #expect(model.selection.isEmpty)
        #expect(model.selectedCount == nil)
    }

    @Test func `no count for one selected card`() {
        receive([5, 4, 3])
        model.select(5)
        #expect(model.selectedCount == nil)
    }

    @Test func `count for two selected cards`() {
        receive([5, 4, 3])
        model.select(5)
        model.extendSelection(to: 4)
        #expect(model.selectedCount == 2)
    }

    @Test func `count for select all`() {
        receive([5, 4, 3])
        model.select(5)
        model.selectAll()
        #expect(model.selectedCount == 3)
    }
}
