import Foundation
import GRDB
import Testing
@testable import Store

struct TextRecognitionTests {
    let database: AppDatabase
    let repository: CardRepository

    init() throws {
        database = try AppDatabase.temporary()
        repository = CardRepository(database: database)
    }

    @Test(arguments: [
        (CardKind.image, TextRecognitionState.pending),
        (.text, .notApplicable),
        (.file, .notApplicable)
    ])
    func `only image cards await recognition`(kind: CardKind, expected: TextRecognitionState) async throws {
        let id = try await record(kind, hash: 1)

        #expect(try await state(of: id) == expected)
    }

    @Test func `newest pending card comes first`() async throws {
        let older = try await record(.image, hash: 1)
        let newer = try await record(.image, hash: 2)

        #expect(try await repository.nextCardAwaitingTextRecognition() == newer)
        try await repository.saveRecognizedText("", ofCard: newer)
        #expect(try await repository.nextCardAwaitingTextRecognition() == older)
        try await repository.markTextRecognitionFailed(ofCard: older)
        #expect(try await repository.nextCardAwaitingTextRecognition() == nil)
    }

    @Test func `saving text of a card that is no longer pending changes nothing`() async throws {
        let id = try await record(.image, hash: 1)
        try await repository.markTextRecognitionFailed(ofCard: id)

        try await repository.saveRecognizedText("Receipt", ofCard: id)

        #expect(try await state(of: id) == .failed)
        #expect(try await repository.search("receipt").isEmpty)
    }

    private func record(_ kind: CardKind, hash: UInt8) async throws -> Int64 {
        try await repository.record(NewCard(
            kind: kind,
            representations: [Representation(itemIndex: 0, uti: "public.data", data: Data([hash]))],
            contentHash: Data([hash]),
            previewText: nil,
            metadata: nil,
            sourceApp: SourceApp(bundleID: "com.example.notes", name: "Notes")
        ))
    }

    private func state(of id: Int64) async throws -> TextRecognitionState? {
        try await database.pool.read { connection in
            try Int.fetchOne(connection, sql: "SELECT ocr_state FROM card WHERE id = ?", arguments: [id])
                .flatMap(TextRecognitionState.init(rawValue:))
        }
    }
}
