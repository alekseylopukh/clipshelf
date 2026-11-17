import AppIntents
import Integrations

struct GetCardAtIndexIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Card at Index"
    static let description = IntentDescription(
        "Gets a card by its position, starting at 1. Leave Board empty to count from the newest card in History.",
        categoryName: "Cards"
    )

    @Parameter(title: "Index", default: 1)
    var index: Int

    @Parameter(title: "Board")
    var board: BoardEntity?

    @Dependency private var handler: CardIntentHandler

    static var parameterSummary: some ParameterSummary {
        Summary("Get card \(\.$index) on \(\.$board)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<CardEntity> {
        let card = try await handler.card(at: index, in: board?.list ?? .history)
        return try await .result(value: CardEntity(card, handler: handler))
    }
}
