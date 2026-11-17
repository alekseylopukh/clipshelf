import Foundation
import Pasting
import Store
import Testing
@testable import ShelfUI

@MainActor
final class SequencePanelModelTests {
    private let suiteName = "SequencePanelModelTests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makeModel(onPasteAll: @escaping ([Int64]) -> Void = { _ in }) -> SequencePanelModel {
        SequencePanelModel(
            sequence: PasteSequence(defaults: defaults),
            loadCards: { ids in ids.map { CardSummary(id: $0, kind: .text, createdAt: .now) } },
            onPasteAll: onPasteAll
        )
    }

    @Test func `panel model reflects queue`() async throws {
        let model = makeModel()
        model.sequence.add([3, 1, 2])
        await model.refreshCards()

        #expect(model.rows.map(\.id) == model.sequence.entries.map(\.id))
        #expect(model.rows.map { $0.card?.id } == [3, 1, 2])
        #expect(model.rows.map(\.isNext) == [true, false, false])

        let head = try #require(model.sequence.head)
        model.sequence.didPaste(head.id)
        await model.refreshCards()

        #expect(model.rows.map { $0.card?.id } == [1, 2])
        #expect(model.rows.map(\.isNext) == [true, false])
        #expect(model.cards.keys.sorted() == [1, 2])
    }

    @Test func `removing selected rows keeps the rest in order`() {
        let model = makeModel()
        model.sequence.add([1, 2, 3])
        let entries = model.sequence.entries

        model.remove([entries[0].id, entries[2].id])

        #expect(model.sequence.entries.map(\.cardID) == [2])
        model.sequence.undo()
        #expect(model.sequence.entries.map(\.cardID) == [2, 3])
    }

    @Test func `paste all hands remaining cards over and closes`() {
        var pasted: [Int64] = []
        let model = makeModel { pasted = $0 }
        model.sequence.add([4, 5])

        model.pasteAll()

        #expect(pasted == [4, 5])
        #expect(model.sequence.isOpen == false)
        #expect(model.rows.isEmpty)
    }
}
