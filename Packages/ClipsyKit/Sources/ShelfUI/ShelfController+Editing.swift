import AppKit
import os
import Store

public extension ShelfController {
    typealias ReplaceText = @Sendable (Int64, [Representation]) async throws -> Void
    typealias AddText = @Sendable ([Representation], CardList) async throws -> Void
}

extension ShelfController {
    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    func handleCardCommandKey(_ key: String, modifiers: NSEvent.ModifierFlags, isRepeat: Bool) -> Bool {
        if modifiers == .command, key == "n" {
            if !isRepeat {
                beginNewTextCard()
            }
            return true
        }
        let commandKeys = modifiers == .command ? Self.commandKeys
            : modifiers == [.shift, .command] ? Self.shiftCommandKeys : [:]
        guard let command = commandKeys[key] else { return false }
        if !isRepeat {
            perform(command, on: model.selectedCards.map(\.id))
        }
        return true
    }

    func beginNewTextCard() {
        actions.textEditor = makeTextEditor(for: .new(model.tab))
    }

    func edit(_ ids: [Int64]) {
        guard ids.count == 1, let card = model.cards.first(where: { $0.id == ids.first }), card.kind == .text else {
            return
        }
        Task {
            await openEditor(for: card.id)
        }
    }

    private func openEditor(for cardID: Int64) async {
        do {
            let loaded = try await representations(cardID)
            guard isShown else { return }
            actions.textEditor = makeTextEditor(for: .card(cardID), representations: loaded)
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("loading text failed: \(String(describing: type(of: error)), privacy: .public)")
            await presentError(error, title: String(
                localized: "Clipsy can’t edit this card.",
                comment: "Title of the alert shown when a card's text cannot be loaded for editing"
            ))
        }
    }

    private func makeTextEditor(
        for target: TextCardEditor.Target,
        representations: [Representation] = []
    ) -> TextCardEditor {
        TextCardEditor(target: target, representations: representations) { [replaceText, addText] target, text in
            switch target {
            case let .card(id):
                try await replaceText(id, text)
            case let .new(list):
                try await addText(text, list)
            }
        }
    }
}
