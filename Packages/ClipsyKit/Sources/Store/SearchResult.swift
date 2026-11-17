public struct SearchResult: Sendable, Equatable, Identifiable {
    public var card: CardSummary
    public var titleMatches: [Range<String.Index>]
    public var previewMatches: [Range<String.Index>]

    public var id: Int64 {
        card.id
    }
}
