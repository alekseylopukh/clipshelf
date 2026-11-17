import CoreTransferable
import UniformTypeIdentifiers

/// a board capsule dragged to a new place among the tabs
struct BoardReference: Codable, Sendable, Transferable {
    let boardID: Int64

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .clipsyBoardReference)
    }
}

extension UTType {
    static let clipsyBoardReference = UTType(exportedAs: "app.gonar.clipsy.board-reference")
}
