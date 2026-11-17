import Foundation
import Store
import Testing
@testable import ShelfUI

@MainActor
struct CardDeletionTests {
    let repository: CardRepository
    let deletion: CardDeletion
    let holder = DeletionHolder()

    init() throws {
        let repository = try CardRepository(database: AppDatabase.temporary())
        self.repository = repository
        deletion = CardDeletion(
            delete: { try await repository.delete(cards: $0, in: $1) },
            restore: { try await repository.restore($0) }
        )
    }

    @Test func `delete several needs confirmation`() async throws {
        let ids = try await record(3)
        var asked: [Int] = []

        let declined = try await deletion.delete([.history: Array(ids.prefix(2))]) { count in
            asked.append(count)
            return false
        }
        #expect(declined == false)
        #expect(try await historyIDs() == ids.reversed())

        let confirmed = try await deletion.delete([.history: Array(ids.prefix(2))]) { count in
            asked.append(count)
            return true
        }
        #expect(confirmed)
        #expect(try await historyIDs() == [ids[2]])
        #expect(asked == [2, 2])
    }

    @Test func `delete one needs no confirmation`() async throws {
        let ids = try await record(2)

        let deleted = try await deletion.delete([.history: [ids[0]]]) { _ in
            Issue.record("one card must be deleted without asking")
            return false
        }

        #expect(deleted)
        #expect(try await historyIDs() == [ids[1]])
    }

    @Test func `undo restores deleted cards`() async throws {
        let ids = try await record(3)
        _ = try await deletion.delete([.history: [ids[0]]]) { _ in true }
        _ = try await deletion.delete([.history: [ids[1], ids[2]]]) { _ in true }
        #expect(try await historyIDs().isEmpty)

        try await deletion.undo()
        #expect(try await historyIDs() == [ids[2], ids[1]])
        try await deletion.undo()
        #expect(try await historyIDs() == ids.reversed())
        #expect(deletion.canUndo == false)
    }

    @Test func `delete across lists is one undo step`() async throws {
        let ids = try await record(2)
        let boardID = try await repository.createBoard(named: "Work", color: "blue")
        try await repository.addCards([ids[1]], toBoard: boardID)

        _ = try await deletion.delete([.history: [ids[0]], .board(id: boardID): [ids[1]]]) { _ in true }
        #expect(try await historyIDs() == [ids[1]])
        #expect(try await repository.cards(in: .board(id: boardID)).isEmpty)

        try await deletion.undo()
        #expect(try await historyIDs() == ids.reversed())
        #expect(try await repository.cards(in: .board(id: boardID)).map(\.id) == [ids[1]])
        #expect(deletion.canUndo == false)
    }

    @Test func `discarded undo restores nothing`() async throws {
        let ids = try await record(1)
        _ = try await deletion.delete([.history: ids]) { _ in true }

        deletion.discardUndo()
        try await deletion.undo()

        #expect(try await historyIDs().isEmpty)
    }

    @Test func `undo history discarded during delete stays empty`() async throws {
        let ids = try await record(1)
        let deletion = CardDeletion(
            delete: { [repository, holder] ids, list in
                let deleted = try await repository.delete(cards: ids, in: list)
                await holder.deletion?.discardUndo()
                return deleted
            },
            restore: { [repository] in try await repository.restore($0) }
        )
        holder.deletion = deletion

        _ = try await deletion.delete([.history: ids]) { _ in true }

        #expect(deletion.canUndo == false)
    }

    @Test func `undo history discarded during undo does not crash`() async throws {
        let ids = try await record(1)
        let deletion = CardDeletion(
            delete: { [repository] in try await repository.delete(cards: $0, in: $1) },
            restore: { [repository, holder] deleted in
                let restored = try await repository.restore(deleted)
                await holder.deletion?.discardUndo()
                return restored
            }
        )
        holder.deletion = deletion
        _ = try await deletion.delete([.history: ids]) { _ in true }

        try await deletion.undo()

        #expect(try await historyIDs() == ids)
        #expect(deletion.canUndo == false)
    }

    private func record(_ count: UInt8) async throws -> [Int64] {
        var ids: [Int64] = []
        for byte in 1 ... count {
            try await ids.append(repository.record(
                NewCard(
                    kind: .text,
                    representations: [Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data([byte]))],
                    contentHash: Data([byte]),
                    previewText: "Card \(byte)",
                    metadata: nil,
                    sourceApp: SourceApp(bundleID: "com.example.notes", name: "Notes")
                ),
                at: Date(timeIntervalSince1970: TimeInterval(byte))
            ))
        }
        return ids
    }

    private func historyIDs() async throws -> [Int64] {
        try await repository.cards(in: .history).map(\.id)
    }
}

@MainActor
final class DeletionHolder {
    var deletion: CardDeletion?
}
