import AppIntents
import Integrations

struct GetLatestCardIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Latest Card of Type"
    static let description = IntentDescription("Gets the newest card of a type from History.", categoryName: "Cards")

    @Parameter(title: "Type", default: .text)
    var type: CardType

    @Dependency private var handler: CardIntentHandler

    static var parameterSummary: some ParameterSummary {
        Summary("Get the latest \(\.$type) card")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<CardEntity> {
        let card = try await handler.latestCard(of: type.kind)
        return try await .result(value: CardEntity(card, handler: handler))
    }
}
