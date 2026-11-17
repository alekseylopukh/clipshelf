import Foundation
import GRDB
import Testing
@testable import Store

struct CardEditingTests {
    let database: AppDatabase
    let repository: CardRepository

    init() throws {
        database = try AppDatabase.temporary()
        repository = CardRepository(database: database)
    }

    @Test(arguments: ["", "  \n "])
    func `empty title clears`(title: String) async throws {
        let id = try await record(byte: 1, at: 10)
        try await repository.rename(card: id, to: "Invoice")

        try await repository.rename(card: id, to: title)

        #expect(try await repository.cards(in: .history).first?.title == nil)
        #expect(try await searchTitle(of: id) == nil)
    }

    @Test func `rename updates search row`() async throws {
        let id = try await record(byte: 1, at: 10)

        try await repository.rename(card: id, to: "  Quarterly invoice ")

        #expect(try await repository.cards(in: .history).first?.title == "Quarterly invoice")
        #expect(try await searchTitle(of: id) == "Quarterly invoice")
        #expect(try await repository.search("quarter").map(\.card.id) == [id])
    }

    @Test func `rename of a missing card throws`() async throws {
        await #expect(throws: RecordError.self) {
            try await repository.rename(card: 42, to: "A")
        }
    }

    private func record(byte: UInt8, at time: TimeInterval) async throws -> Int64 {
        try await repository.record(
            NewCard(
                kind: .text,
                representations: [
                    Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data([byte]))
                ],
                contentHash: Data([byte]),
                previewText: "Card \(byte)",
                metadata: nil,
                sourceApp: SourceApp(bundleID: "com.example.notes", name: "Notes")
            ),
            at: Date(timeIntervalSince1970: time)
        )
    }

    private func searchTitle(of id: Int64) async throws -> String? {
        try await database.pool.read { connection in
            try String.fetchOne(connection, sql: "SELECT title FROM card_search WHERE rowid = ?", arguments: [id])
        }
    }
}
