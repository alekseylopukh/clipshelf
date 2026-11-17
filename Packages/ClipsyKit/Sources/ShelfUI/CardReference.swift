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

extension UTType {
    static let clipsyCardReference = UTType(exportedAs: "app.gonar.clipsy.card-reference")
}
