public struct SearchResult: Sendable, Equatable, Identifiable {
    public var card: CardSummary
    public var titleMatches: [Range<String.Index>]
    public var previewMatches: [Range<String.Index>]

    public init(card: CardSummary, titleMatches: [Range<String.Index>], previewMatches: [Range<String.Index>]) {
        self.card = card
        self.titleMatches = titleMatches
        self.previewMatches = previewMatches
    }

    public var id: Int64 {
        card.id
    }
}
