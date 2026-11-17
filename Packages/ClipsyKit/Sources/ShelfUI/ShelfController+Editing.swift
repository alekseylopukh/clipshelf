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

    public func showSearch(for text: String) {
        show()
        model.search(for: text)
    }

    public func showNewTextCard(text: String) {
        show()
        guard actions.textEditor == nil else { return }
        let plainText = Representation(
            itemIndex: 0,
            uti: NSPasteboard.PasteboardType.string.rawValue,
            data: Data(text.utf8)
        )
        actions.textEditor = makeTextEditor(for: .new(model.tab), representations: [plainText])
    }

    func edit(_ ids: [Int64]) {
        guard ids.count == 1, let card = model.cards.first(where: { $0.id == ids.first }) else { return }
        let id = card.id
        switch card.kind {
        case .text:
            Task {
                await openEditor(for: id)
            }
        case .link:
            actions.linkEditor = LinkCardEditor(card: card) { [replaceText] in
                try await replaceText(id, $0)
            } rename: { [renameCard] in
                try await renameCard(id, $0)
            }
        case .color:
            actions.colorEditor = ColorCardEditor(card: card) { [replaceText] in
                try await replaceText(id, $0)
            }
        case .image, .file, .unknown:
            return
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
