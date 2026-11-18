import Store

extension ShelfModel {
    static func encodeTab(_ list: CardList) -> String {
        switch list {
        case .history: "history"
        case let .board(id): "board:\(id)"
        }
    }

    static func decodeTab(_ value: String?) -> CardList? {
        guard let value else { return nil }
        if value == "history" {
            return .history
        }
        guard value.hasPrefix("board:"), let id = Int64(value.dropFirst("board:".count)) else { return nil }
        return .board(id: id)
    }
}
