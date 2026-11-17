import Foundation
import GRDB

public struct Board: Sendable, Equatable, Identifiable {
    public var id: Int64
    public var name: String
    public var color: String
    public var createdAt: Date
}

extension Board: FetchableRecord {
    public init(row: Row) {
        id = row["id"]
        name = row["name"]
        color = row["color"]
        createdAt = Date(timeIntervalSince1970: row["created_at"])
    }
}
