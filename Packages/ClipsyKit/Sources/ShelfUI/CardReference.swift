import CoreTransferable
import UniformTypeIdentifiers

/// a card dragged inside Clipsy, for example from the shelf into the Sequence panel
public struct CardReference: Codable, Sendable, Transferable {
    public let cardID: Int64

    public init(cardID: Int64) {
        self.cardID = cardID
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .clipsyCardReference)
    }
}

extension [CardReference] {
    /// a dragged card puts its reference on each of its items, so a multi-file card arrives more than once
    var cardIDs: [Int64] {
        var seen = Set<Int64>()
        return map(\.cardID).filter { seen.insert($0).inserted }
    }
}

extension UTType {
    static let clipsyCardReference = UTType(exportedAs: "app.gonar.clipsy.card-reference")
}
