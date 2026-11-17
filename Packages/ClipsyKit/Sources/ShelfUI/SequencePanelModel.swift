import Foundation
import Observation
import os
import Pasting
import Store

@MainActor
@Observable
public final class SequencePanelModel {
    public typealias CardLoading = @Sendable ([Int64]) async throws -> [CardSummary]

    struct Row: Identifiable, Equatable {
        let id: PasteSequence.Entry.ID
        let card: CardSummary?
        let isNext: Bool
    }

    public let sequence: PasteSequence
    private(set) var cards: [Int64: CardSummary] = [:]

    @ObservationIgnored private let loadCards: CardLoading
    @ObservationIgnored private let onPasteAll: ([Int64]) -> Void

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Sequence")

    /// `onPasteAll` receives the remaining card ids in paste order, after the Sequence has closed
    public init(
        sequence: PasteSequence,
        loadCards: @escaping CardLoading,
        onPasteAll: @escaping ([Int64]) -> Void
    ) {
        self.sequence = sequence
        self.loadCards = loadCards
        self.onPasteAll = onPasteAll
    }

    var rows: [Row] {
        let headID = sequence.head?.id
        return sequence.entries.map { Row(id: $0.id, card: cards[$0.cardID], isNext: $0.id == headID) }
    }

    var cardIDs: [Int64] {
        sequence.entries.map(\.cardID)
    }

    func refreshCards() async {
        let ids = cardIDs
        do {
            let summaries = try await loadCards(ids)
            guard ids == cardIDs else { return }
            cards = Dictionary(summaries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("loading sequence cards failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    func remove(_ entryIDs: Set<PasteSequence.Entry.ID>) {
        for entry in sequence.entries where entryIDs.contains(entry.id) {
            sequence.remove(entry.id)
        }
    }

    public func pasteAll() {
        let cardIDs = sequence.pasteAll()
        guard cardIDs.isEmpty == false else { return }
        onPasteAll(cardIDs)
    }
}
