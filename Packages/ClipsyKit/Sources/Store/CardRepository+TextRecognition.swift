import Foundation
import GRDB

public extension CardRepository {
    func observeTextRecognitionBacklog() -> some AsyncSequence<Int64?, any Error> & Sendable {
        ValueObservation
            .tracking(Self.newestCardAwaitingTextRecognition)
            .removeDuplicates()
            .values(in: database.pool, bufferingPolicy: .bufferingNewest(1))
    }

    @concurrent
    func nextCardAwaitingTextRecognition() async throws -> Int64? {
        try await database.pool.read(Self.newestCardAwaitingTextRecognition)
    }

    @concurrent
    func saveRecognizedText(_ text: String, ofCard id: Int64) async throws {
        try await database.pool.write { connection in
            try connection.execute(
                sql: "UPDATE card SET ocr_state = ? WHERE id = ? AND ocr_state = ?",
                arguments: [TextRecognitionState.done.rawValue, id, TextRecognitionState.pending.rawValue]
            )
            guard connection.changesCount > 0 else { return }
            try connection.execute(
                sql: "UPDATE card_search SET ocr_text = ? WHERE rowid = ?",
                arguments: [text.isEmpty ? nil : text, id]
            )
        }
    }

    @concurrent
    func markTextRecognitionFailed(ofCard id: Int64) async throws {
        try await database.pool.write { connection in
            try connection.execute(
                sql: "UPDATE card SET ocr_state = ? WHERE id = ? AND ocr_state = ?",
                arguments: [TextRecognitionState.failed.rawValue, id, TextRecognitionState.pending.rawValue]
            )
        }
    }

    private static func newestCardAwaitingTextRecognition(in connection: Database) throws -> Int64? {
        try Int64.fetchOne(
            connection,
            sql: "SELECT id FROM card WHERE ocr_state = ? ORDER BY id DESC LIMIT 1",
            arguments: [TextRecognitionState.pending.rawValue]
        )
    }
}
