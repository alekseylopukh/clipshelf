import Foundation
import GRDB

public struct CardRepository: Sendable {
    let database: AppDatabase
    let payloads: PayloadStore

    public init(database: AppDatabase) {
        self.database = database
        payloads = PayloadStore(directory: database.directory)
    }

    public var thumbnailsDirectory: URL {
        payloads.thumbnailsDirectory
    }

    @discardableResult
    @concurrent
    public func record(_ card: NewCard, at date: Date = .now) async throws -> Int64 {
        try await database.pool.write { connection in
            let sourceAppID = try Self.upsert(card.sourceApp, in: connection)
            let time = date.timeIntervalSince1970
            if let id = try Int64.fetchOne(
                connection,
                sql: "SELECT id FROM card WHERE content_hash = ?",
                arguments: [card.contentHash]
            ) {
                try connection.execute(
                    sql: "UPDATE card SET last_copied_at = ?, source_app_id = ? WHERE id = ?",
                    arguments: [time, sourceAppID, id]
                )
                try connection.execute(
                    sql: "UPDATE card_search SET app_name = ? WHERE rowid = ?",
                    arguments: [card.sourceApp.name, id]
                )
                return id
            }

            return try insertCard(card, sourceAppID: sourceAppID, at: time, board: nil, in: connection)
        }
    }

    @concurrent
    public func representations(of cardID: Int64) async throws -> [Representation] {
        try await database.pool.read { [payloads] connection in
            try Row.fetchAll(
                connection,
                sql: """
                SELECT item_index, uti, inline_data, payload_hash FROM representation
                WHERE card_id = ? ORDER BY item_index, type_index
                """,
                arguments: [cardID]
            ).map { row in
                let payload: Payload = if let hash: String = row["payload_hash"] {
                    .file(hash: hash)
                } else {
                    .inline(row["inline_data"] ?? Data())
                }
                return try Representation(
                    itemIndex: row["item_index"],
                    uti: row["uti"],
                    data: payloads.data(for: payload)
                )
            }
        }
    }

    /// a card without a board goes to History
    func insertCard(
        _ card: NewCard,
        sourceAppID: Int64,
        at time: Double,
        board: (id: Int64, position: Double)?,
        in connection: Database
    ) throws -> Int64 {
        try connection.execute(
            sql: """
            INSERT INTO card (kind, content_hash, preview_text, metadata, source_app_id,
                              byte_size, created_at, last_copied_at, board_id, board_position, ocr_state)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                card.kind.rawValue, card.contentHash, card.previewText, card.metadata, sourceAppID,
                card.byteSize, time, board == nil ? time : nil, board?.id, board?.position,
                card.kind == .image ? TextRecognitionState.pending.rawValue : TextRecognitionState.notApplicable
                    .rawValue
            ]
        )
        let id = connection.lastInsertedRowID

        try Self.insert(card.representations, of: id, into: payloads, in: connection)

        try connection.execute(
            sql: "INSERT INTO card_search (rowid, body, url, file_names, app_name) VALUES (?, ?, ?, ?, ?)",
            arguments: [id, card.searchBody ?? card.previewText, card.url, card.joinedFileNames, card.sourceApp.name]
        )
        return id
    }

    static func insert(
        _ representations: [Representation],
        of cardID: Int64,
        into payloads: PayloadStore,
        in connection: Database
    ) throws {
        var nextTypeIndex: [Int: Int] = [:]
        for representation in representations {
            let typeIndex = nextTypeIndex[representation.itemIndex, default: 0]
            nextTypeIndex[representation.itemIndex] = typeIndex + 1
            let (inlineData, payloadHash): (Data?, String?) = switch try payloads.store(representation.data) {
            case let .inline(data): (data, nil)
            case let .file(hash): (nil, hash)
            }
            try connection.execute(
                sql: """
                INSERT INTO representation (card_id, item_index, type_index, uti, inline_data, payload_hash, byte_size)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    cardID, representation.itemIndex, typeIndex, representation.uti,
                    inlineData, payloadHash, representation.data.count
                ]
            )
        }
    }

    static func upsert(_ sourceApp: SourceApp, in connection: Database) throws -> Int64 {
        guard let id = try Int64.fetchOne(
            connection,
            sql: """
            INSERT INTO source_app (bundle_id, name) VALUES (?, ?)
            ON CONFLICT (bundle_id) DO UPDATE SET name = excluded.name
            RETURNING id
            """,
            arguments: [sourceApp.bundleID, sourceApp.name]
        ) else { fatalError("upsert with RETURNING always yields one row") }
        return id
    }
}
