import Foundation
import GRDB

/// what `CardRepository.delete(cards:in:)` removed, for `restore(_:)`
public struct DeletedCards: Sendable {
    let list: CardList
    let cards: [Card]

    struct Card: Sendable {
        var record: CardRecord
        var representations: [RepresentationRecord]
        var search: SearchRecord?
    }

    struct CardRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "card"

        var id: Int64?
        var kind: Int
        var contentHash: Data
        var title: String?
        var previewText: String?
        var metadata: String?
        var sourceAppID: Int64?
        var byteSize: Int
        var createdAt: Double
        var lastCopiedAt: Double?
        var boardID: Int64?
        var boardPosition: Double?
        var ocrState: Int

        enum CodingKeys: String, CodingKey {
            case id, kind, title, metadata
            case contentHash = "content_hash"
            case previewText = "preview_text"
            case sourceAppID = "source_app_id"
            case byteSize = "byte_size"
            case createdAt = "created_at"
            case lastCopiedAt = "last_copied_at"
            case boardID = "board_id"
            case boardPosition = "board_position"
            case ocrState = "ocr_state"
        }
    }

    struct RepresentationRecord: Codable, Sendable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "representation"

        var cardID: Int64
        var itemIndex: Int
        var typeIndex: Int
        var uti: String
        var inlineData: Data?
        var payloadHash: String?
        var byteSize: Int

        enum CodingKeys: String, CodingKey {
            case uti
            case cardID = "card_id"
            case itemIndex = "item_index"
            case typeIndex = "type_index"
            case inlineData = "inline_data"
            case payloadHash = "payload_hash"
            case byteSize = "byte_size"
        }
    }

    struct SearchRecord: Sendable {
        var title: String?
        var body: String?
        var url: String?
        var fileNames: String?
        var ocrText: String?
        var appName: String?
    }
}
