import Foundation
import GRDB

public struct CardSummary: Sendable, Equatable, Identifiable {
    public var id: Int64
    public var kind: CardKind
    public var title: String?
    public var preview: String?
    public var metadata: String?
    public var sourceApp: SourceApp?
    public var createdAt: Date
    public var lastCopiedAt: Date?
    public var boardID: Int64?
}

extension CardSummary: FetchableRecord {
    static let selection = """
    SELECT card.id, card.kind, card.title, card.preview_text, card.metadata,
           card.created_at, card.last_copied_at, card.board_id,
           source_app.bundle_id, source_app.name AS app_name
    FROM card LEFT JOIN source_app ON source_app.id = card.source_app_id
    """

    public init(row: Row) throws {
        let rawKind: Int = row["kind"]
        guard let kind = CardKind(rawValue: rawKind) else {
            throw DatabaseError(message: "unknown card kind \(rawKind)")
        }
        id = row["id"]
        self.kind = kind
        title = row["title"]
        preview = row["preview_text"]
        metadata = row["metadata"]
        sourceApp = if let bundleID: String = row["bundle_id"] {
            SourceApp(bundleID: bundleID, name: row["app_name"])
        } else {
            nil
        }
        createdAt = Date(timeIntervalSince1970: row["created_at"])
        lastCopiedAt = (row["last_copied_at"] as Double?).map(Date.init(timeIntervalSince1970:))
        boardID = row["board_id"]
    }
}
