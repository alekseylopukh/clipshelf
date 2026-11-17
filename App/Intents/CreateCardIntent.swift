import AppIntents
import Integrations

struct CreateCardIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Card"
    static let description = IntentDescription(
        "Adds a text card to Clipsy. Leave Board empty to add it to History.",
        categoryName: "Cards"
    )

    @Parameter(title: "Text", inputOptions: String.IntentInputOptions(multiline: true))
    var text: String

    @Parameter(title: "Board")
    var board: BoardEntity?

    @Dependency private var handler: CardIntentHandler

    static var parameterSummary: some ParameterSummary {
        Summary("Create a card with \(\.$text) on \(\.$board)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<CardEntity> {
        let card = try await handler.createCard(text: text, in: board?.list ?? .history)
        return try await .result(value: CardEntity(card, handler: handler))
    }
}
