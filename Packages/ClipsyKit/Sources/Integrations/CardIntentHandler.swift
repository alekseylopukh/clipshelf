import Capture
import DesignSystem
import Foundation
import Store
import UniformTypeIdentifiers

public struct CardIntentHandler: Sendable {
    let repository: CardRepository

    public init(repository: CardRepository) {
        self.repository = repository
    }

    public func createCard(text: String, in list: CardList) async throws -> CardSummary {
        guard text.isEmpty == false else { throw CardIntentError.emptyText }
        let card = await NewCard.editedText([
            Representation(itemIndex: 0, uti: UTType.utf8PlainText.identifier, data: Data(text.utf8))
        ])
        let id: Int64
        do {
            id = try await repository.add(card, to: list)
        } catch CardEditError.duplicateContent {
            throw CardIntentError.duplicateContent
        }
        guard let summary = try await repository.cards(withIDs: [id]).first else { throw CardIntentError.cardNotFound }
        return summary
    }

    public func createBoard(named name: String) async throws -> Board {
        let color = try await BoardColor.forNewBoard(usedColors: repository.boards().map(\.color))
        let id = try await repository.createBoard(named: name, color: color.rawValue)
        guard let board = try await repository.boards().first(where: { $0.id == id }) else {
            throw CardIntentError.boardNotFound
        }
        return board
    }

    /// `position` 1 is the first card, as the Shelf shows it
    public func card(at position: Int, in list: CardList) async throws -> CardSummary {
        guard position >= 1, let card = try await repository.card(at: position - 1, in: list) else {
            throw CardIntentError.noCard(at: position)
        }
        return card
    }

    public func latestCard(of kind: CardKind) async throws -> CardSummary {
        guard let card = try await repository.latestCard(of: kind) else { throw CardIntentError.noCardOfKind }
        return card
    }

    public func cards(withIDs ids: [Int64]) async throws -> [CardSummary] {
        try await repository.cards(withIDs: ids)
    }

    public func boards() async throws -> [Board] {
        try await repository.boards()
    }

    public func text(of card: CardSummary) async throws -> String? {
        let plainText = try await repository.representations(of: card.id)
            .first { $0.uti == UTType.utf8PlainText.identifier }
            .flatMap { String(data: $0.data, encoding: .utf8) }
        return plainText ?? card.preview
    }
}
