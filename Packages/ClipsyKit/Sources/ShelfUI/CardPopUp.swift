struct CardPopUp: Equatable {
    enum Kind {
        case addToBoard
        case openWith
        case share
    }

    let kind: Kind
    let anchorID: Int64
    let cardIDs: [Int64]
}
