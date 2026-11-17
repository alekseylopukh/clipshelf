import AppIntents
import Foundation
import Integrations
import Store

struct CardEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Card"
    static let defaultQuery = CardEntityQuery()

    let id: Int

    @Property(title: "Title")
    var title: String

    @Property(title: "Type")
    var type: CardType

    @Property(title: "Text")
    var text: String?

    @Property(title: "Source App")
    var sourceApp: String?

    @Property(title: "Created")
    var createdAt: Date

    @Property(title: "Last Copied")
    var lastCopiedAt: Date?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: sourceApp.map { "\($0)" })
    }

    init(_ card: CardSummary, handler: CardIntentHandler) async throws {
        id = Int(card.id)
        let text = try await handler.text(of: card)
        title = card.title ?? text ?? card.preview ?? ""
        type = CardType(card.kind)
        self.text = text
        sourceApp = card.sourceApp?.name
        createdAt = card.createdAt
        lastCopiedAt = card.lastCopiedAt
    }
}

struct CardEntityQuery: EntityQuery {
    @Dependency private var handler: CardIntentHandler

    func entities(for identifiers: [Int]) async throws -> [CardEntity] {
        var entities: [CardEntity] = []
        for card in try await handler.cards(withIDs: identifiers.map(Int64.init)) {
            try await entities.append(CardEntity(card, handler: handler))
        }
        return entities
    }
}
