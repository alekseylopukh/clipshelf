public struct CardFilter: Sendable, Equatable {
    public var kind: CardKind?
    public var sourceAppBundleID: String?
    public var dateRange: DateRangeFilter?
    public var boardID: Int64?

    public init(
        kind: CardKind? = nil,
        sourceAppBundleID: String? = nil,
        dateRange: DateRangeFilter? = nil,
        boardID: Int64? = nil
    ) {
        self.kind = kind
        self.sourceAppBundleID = sourceAppBundleID
        self.dateRange = dateRange
        self.boardID = boardID
    }

    public var isEmpty: Bool {
        self == CardFilter()
    }
}
