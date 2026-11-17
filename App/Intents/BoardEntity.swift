import AppIntents
import Integrations
import Store

struct BoardEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Board"
    static let defaultQuery = BoardEntityQuery()

    let id: Int

    @Property(title: "Name")
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    var list: CardList {
        .board(id: Int64(id))
    }

    init(_ board: Board) {
        id = Int(board.id)
        name = board.name
    }
}

struct BoardEntityQuery: EnumerableEntityQuery {
    @Dependency private var handler: CardIntentHandler

    func allEntities() async throws -> [BoardEntity] {
        try await handler.boards().map(BoardEntity.init)
    }

    func entities(for identifiers: [Int]) async throws -> [BoardEntity] {
        try await allEntities().filter { identifiers.contains($0.id) }
    }
}
