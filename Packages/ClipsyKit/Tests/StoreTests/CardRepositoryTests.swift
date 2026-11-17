import Foundation
import GRDB
import Testing
@testable import Store

struct CardRepositoryTests {
    let database: AppDatabase
    let repository: CardRepository

    init() throws {
        database = try AppDatabase.temporary()
        repository = CardRepository(database: database)
    }

    @Test func `new card is inserted with search row`() async throws {
        let id = try await repository.record(
            Self.textCard("Hello world", hash: 1, app: Self.notes),
            at: Date(timeIntervalSince1970: 100)
        )

        let card = try await storedCard(id)
        #expect(card.kind == CardKind.text.rawValue)
        #expect(card.previewText == "Hello world")
        #expect(card.createdAt == 100)
        #expect(card.lastCopiedAt == 100)
        #expect(card.byteSize == 11)
        let matches = try await database.pool.read { connection in
            try Int64.fetchAll(
                connection,
                sql: "SELECT rowid FROM card_search WHERE card_search MATCH ?",
                arguments: ["hello AND app_name:notes"]
            )
        }
        #expect(matches == [id])
    }

    @Test func `same hash moves card to top`() async throws {
        let first = try await repository.record(
            Self.textCard("A", hash: 1, app: Self.notes),
            at: Date(timeIntervalSince1970: 100)
        )
        try await repository.record(Self.textCard("B", hash: 2, app: Self.notes), at: Date(timeIntervalSince1970: 200))

        let again = try await repository.record(
            Self.textCard("A", hash: 1, app: Self.browser),
            at: Date(timeIntervalSince1970: 300)
        )

        #expect(again == first)
        let history = try await database.pool.read { connection in
            try Int64.fetchAll(connection, sql: "SELECT id FROM card ORDER BY last_copied_at DESC")
        }
        let card = try await storedCard(first)
        let (bundleID, appName) = try await database.pool.read { connection in
            try (
                String.fetchOne(
                    connection,
                    sql: "SELECT bundle_id FROM source_app WHERE id = ?",
                    arguments: [card.sourceAppId]
                ),
                String.fetchOne(connection, sql: "SELECT app_name FROM card_search WHERE rowid = ?", arguments: [first])
            )
        }
        #expect(history.count == 2)
        #expect(history.first == first)
        #expect(card.createdAt == 100)
        #expect(card.lastCopiedAt == 300)
        #expect(bundleID == Self.browser.bundleID)
        #expect(appName == Self.browser.name)
    }

    @Test func `board only card returns to history`() async throws {
        let id = try await repository.record(Self.textCard("A", hash: 1, app: Self.notes))
        try await database.pool.write { connection in
            try connection
                .execute(sql: "INSERT INTO board (id, name, color, position, created_at) VALUES (1, 'B', 'blue', 1, 0)")
            try connection.execute(
                sql: "UPDATE card SET board_id = 1, board_position = 1, last_copied_at = NULL WHERE id = ?",
                arguments: [id]
            )
        }

        try await repository.record(Self.textCard("A", hash: 1, app: Self.notes), at: Date(timeIntervalSince1970: 500))

        let card = try await storedCard(id)
        #expect(card.lastCopiedAt == 500)
        #expect(card.boardId == 1)
    }

    @Test func `representations round trip in order`() async throws {
        let representations = [
            Representation(itemIndex: 0, uti: "public.rtf", data: Data("{\\rtf1 a}".utf8)),
            Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data("a".utf8)),
            Representation(
                itemIndex: 0,
                uti: "public.png",
                data: Data(repeating: 7, count: PayloadStore.inlineLimit * 2)
            ),
            Representation(itemIndex: 1, uti: "public.html", data: Data()),
            Representation(itemIndex: 1, uti: "public.utf8-plain-text", data: Data("b".utf8))
        ]
        var card = Self.textCard("a", hash: 1, app: Self.notes)
        card.representations = representations

        let id = try await repository.record(card)

        #expect(try await repository.representations(of: id) == representations)
    }

    private func storedCard(_ id: Int64) async throws -> StoredCard {
        try #require(try await database.pool.read { connection in
            try StoredCard.fetchOne(connection, sql: "SELECT * FROM card WHERE id = ?", arguments: [id])
        })
    }

    private static let notes = SourceApp(bundleID: "com.example.notes", name: "Notes")
    private static let browser = SourceApp(bundleID: "com.example.browser", name: "Browser")

    private static func textCard(_ text: String, hash: UInt8, app: SourceApp) -> NewCard {
        NewCard(
            kind: .text,
            representations: [Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data(text.utf8))],
            contentHash: Data([hash]),
            previewText: text,
            metadata: nil,
            sourceApp: app
        )
    }
}

private struct StoredCard: Decodable, FetchableRecord {
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    var kind: Int
    var previewText: String?
    var sourceAppId: Int64?
    var byteSize: Int
    var createdAt: Double
    var lastCopiedAt: Double?
    var boardId: Int64?
}
