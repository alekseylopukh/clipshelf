import CoreTransferable

enum TabDropItem: Transferable {
    case board(BoardReference)
    case card(CardReference)

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { (reference: BoardReference) in .board(reference) }
        ProxyRepresentation { (reference: CardReference) in .card(reference) }
    }
}
