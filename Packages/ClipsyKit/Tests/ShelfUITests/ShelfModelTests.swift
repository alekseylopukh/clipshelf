import Foundation
import Store
import Synchronization
import Testing
@testable import ShelfUI

@MainActor
final class ShelfModelTests {
    private let suiteName = "ShelfModelTests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makeModel(
        cards ids: [Int64] = [],
        observe: @escaping ShelfModel.CardObservation = { _ in AsyncThrowingStream { $0.finish() } }
    ) -> ShelfModel {
        let model = ShelfModel(defaults: defaults, observe: observe)
        if !ids.isEmpty {
            model.receive(Self.cards(ids))
        }
        return model
    }

    private static func cards(_ ids: [Int64]) -> [CardSummary] {
        ids.map { CardSummary(id: $0, kind: .text, createdAt: Date(timeIntervalSince1970: TimeInterval($0))) }
    }

    @Test func `arrows move selection`() {
        let model = makeModel(cards: [5, 4, 3])
        model.didOpen()

        model.move(.next)
        #expect(model.selection == [4])
        model.move(.next)
        model.move(.next)
        #expect(model.selection == [3])
        model.move(.previous)
        #expect(model.selection == [4])
        model.selectFirst()
        #expect(model.selection == [5])
        model.move(.previous)
        #expect(model.selection == [5])
        model.selectLast()
        #expect(model.selection == [3])
    }

    @Test func `shift arrow extends`() {
        let model = makeModel(cards: [5, 4, 3, 2])
        model.select(4)

        model.move(.next, extending: true)
        model.move(.next, extending: true)
        #expect(model.selection == [4, 3, 2])

        model.move(.previous, extending: true)
        #expect(model.selection == [4, 3])

        model.move(.previous, extending: true)
        model.move(.previous, extending: true)
        #expect(model.selection == [5, 4])
    }

    @Test func `shift click extends from anchor`() {
        let model = makeModel(cards: [5, 4, 3, 2])
        model.select(4)

        model.extendSelection(to: 2)

        #expect(model.selection == [4, 3, 2])
    }

    @Test func `command click toggles`() {
        let model = makeModel(cards: [5, 4, 3])
        model.select(5)

        model.toggleSelection(of: 3)
        #expect(model.selection == [5, 3])

        model.toggleSelection(of: 5)
        #expect(model.selection == [3])
    }

    @Test func `select all selects current list`() {
        let model = makeModel(cards: [5, 4, 3])

        model.selectAll()

        #expect(model.selection == [5, 4, 3])
    }

    @Test func `selection survives insert at front`() {
        let model = makeModel(cards: [5, 4, 3])
        model.select(4)

        model.receive(Self.cards([6, 5, 4, 3]))
        #expect(model.selection == [4])

        model.move(.next)
        #expect(model.selection == [3])
    }

    @Test func `removed cards leave selection`() {
        let model = makeModel(cards: [5, 4, 3])
        model.selectAll()

        model.receive(Self.cards([5, 3]))

        #expect(model.selection == [5, 3])
    }

    @Test func `open selects newest`() {
        let model = makeModel(cards: [5, 4, 3])
        model.select(3)

        model.didOpen()

        #expect(model.selection == [5])
    }

    @Test func `open before cards arrive selects newest on load`() {
        let model = makeModel()

        model.didOpen()
        #expect(model.selection.isEmpty)
        model.receive(Self.cards([5, 4]))

        #expect(model.selection == [5])
    }

    @Test func `last tab is remembered`() {
        let model = makeModel(cards: [5, 4])

        model.showTab(.board(id: 7))

        #expect(model.cards.isEmpty)
        #expect(model.selection.isEmpty)
        #expect(makeModel().tab == .board(id: 7))
    }

    @Test func `observation feeds current tab`() async {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: [CardSummary].self)
        continuation.yield(Self.cards([2, 1]))
        continuation.yield(Self.cards([3, 2, 1]))
        continuation.finish()
        let requested = Mutex<[CardList]>([])
        let model = makeModel { list in
            requested.withLock { $0.append(list) }
            return stream
        }
        model.showTab(.board(id: 1))

        await model.observeCards()

        #expect(requested.withLock { $0 } == [.board(id: 1)])
        #expect(model.cards.map(\.id) == [3, 2, 1])
        #expect(model.selection == [2])
    }

    @Test func `observation failure is reported`() async {
        struct Failure: Error {}
        let model = makeModel { _ in AsyncThrowingStream { $0.finish(throwing: Failure()) } }

        await model.observeCards()

        #expect(model.observationError is Failure)
    }
}
