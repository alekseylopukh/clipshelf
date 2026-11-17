public struct StorageSummary: Sendable, Equatable {
    public var cardCount: Int
    /// database files plus payload and thumbnail files, as allocated on disk
    public var byteCount: Int64

    public init(cardCount: Int, byteCount: Int64) {
        self.cardCount = cardCount
        self.byteCount = byteCount
    }
}
