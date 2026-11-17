import Foundation
import GRDB

public struct LinkAwaitingPreview: Sendable, Equatable {
    public let url: URL
    /// lowercase hex, the card's thumbnail key
    public let contentHash: String
}

public extension CardRepository {
    /// nil when the card is gone, is not a link, or already has a preview
    @concurrent
    func linkAwaitingPreview(card id: Int64) async throws -> LinkAwaitingPreview? {
        try await database.pool.read { connection in
            guard let row = try Row.fetchOne(
                connection,
                sql: "SELECT metadata, lower(hex(content_hash)) AS content_hash FROM card WHERE id = ? AND kind = ?",
                arguments: [id, CardKind.link.rawValue]
            ) else { return nil }
            let metadata = try Self.decodeMetadata(row["metadata"])
            guard metadata.pageTitle == nil, metadata.pixelWidth == nil,
                  let url = metadata.url.flatMap(URL.init(string:))
            else { return nil }
            return LinkAwaitingPreview(url: url, contentHash: row["content_hash"])
        }
    }

    @concurrent
    func saveLinkPreview(card id: Int64, title: String?, imageSize: (width: Int, height: Int)?) async throws {
        try await database.pool.write { connection in
            guard let row = try Row.fetchOne(connection, sql: "SELECT metadata FROM card WHERE id = ?", arguments: [id])
            else { return }
            var metadata = try Self.decodeMetadata(row["metadata"])
            metadata.pageTitle = title
            metadata.pixelWidth = imageSize?.width
            metadata.pixelHeight = imageSize?.height
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            guard let json = try String(bytes: encoder.encode(metadata), encoding: .utf8) else {
                fatalError("JSONEncoder always produces UTF-8")
            }
            try connection.execute(sql: "UPDATE card SET metadata = ? WHERE id = ?", arguments: [json, id])
            if let title {
                try connection.execute(sql: "UPDATE card_search SET body = ? WHERE rowid = ?", arguments: [title, id])
            }
        }
    }

    private static func decodeMetadata(_ json: String?) throws -> CardMetadata {
        guard let json else { return CardMetadata() }
        return try JSONDecoder().decode(CardMetadata.self, from: Data(json.utf8))
    }
}
