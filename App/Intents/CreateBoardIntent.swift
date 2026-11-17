import AppIntents
import Integrations

struct CreateBoardIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Board"
    static let description = IntentDescription("Adds a board to Clipsy.", categoryName: "Boards")

    @Parameter(title: "Name")
    var name: String

    @Dependency private var handler: CardIntentHandler

    static var parameterSummary: some ParameterSummary {
        Summary("Create a board named \(\.$name)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<BoardEntity> {
        try await .result(value: BoardEntity(handler.createBoard(named: name)))
    }
}
