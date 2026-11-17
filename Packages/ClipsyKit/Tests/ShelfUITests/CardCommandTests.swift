import Foundation
import Store
import Testing
@testable import ShelfUI

struct CardCommandTests {
    private static func card(_ id: Int64, _ kind: CardKind, metadata: String? = nil) -> CardSummary {
        CardSummary(id: id, kind: kind, metadata: metadata, createdAt: Date(timeIntervalSince1970: 0))
    }

    @Test(arguments: [CardList.history, .board(id: 1)])
    func `multi selection menu has only batch items`(list: CardList) {
        let batch: Set<CardCommand> = [.paste, .pasteAsPlainText, .copy, .addToSequence, .removeFromBoard, .delete]

        let menu = CardCommand.menu(for: [Self.card(1, .text), Self.card(2, .link)], in: list)

        #expect(Set(menu.joined()).isSubset(of: batch))
        #expect(menu == [
            [.paste, .pasteAsPlainText], [.copy], [.addToSequence], [list == .history ? .delete : .removeFromBoard]
        ])
    }

    @Test func `text card in history has every applicable item`() {
        let menu = CardCommand.menu(for: [Self.card(1, .text)], in: .history)

        #expect(menu == [
            [.paste, .pasteAsPlainText],
            [.copy, .copyAsPlainText],
            [.rename],
            [.addToSequence],
            [.delete]
        ])
    }

    @Test func `file card on a board can be opened and removed`() {
        let menu = CardCommand.menu(for: [Self.card(1, .file)], in: .board(id: 1))

        #expect(menu == [[.paste], [.copy], [.open], [.rename], [.addToSequence], [.removeFromBoard]])
    }

    @Test func `no cards means no menu`() {
        #expect(CardCommand.menu(for: [], in: .history).isEmpty)
    }

    @Test func `link opens its url`() {
        let card = Self.card(1, .link, metadata: #"{"url":"https:\/\/example.com\/a"}"#)

        #expect(card.openableURLs(in: []) == [URL(string: "https://example.com/a")])
    }

    @Test func `file opens every file url`() {
        let first = URL(filePath: "/tmp/a.txt")
        let second = URL(filePath: "/tmp/b.txt")
        let representations = [
            Representation(itemIndex: 0, uti: "public.file-url", data: first.dataRepresentation),
            Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data("a.txt".utf8)),
            Representation(itemIndex: 1, uti: "public.file-url", data: second.dataRepresentation)
        ]

        #expect(Self.card(1, .file).openableURLs(in: representations) == [first, second])
    }

    @Test func `text has nothing to open`() {
        #expect(Self.card(1, .text).openableURLs(in: []).isEmpty)
    }
}
