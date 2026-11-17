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
        let batch: Set<CardCommand> = [
            .paste, .pasteAsPlainText, .copy, .addToBoard, .addToSequence, .share, .removeFromBoard, .delete
        ]

        let menu = CardCommand.menu(for: [Self.card(1, .text), Self.card(2, .link)], in: list, isSearchResult: false)

        #expect(Set(menu.joined()).isSubset(of: batch))
        #expect(menu == [
            [.paste, .pasteAsPlainText], [.copy], [.addToBoard, .addToSequence], [.share],
            [list == .history ? .delete : .removeFromBoard]
        ])
    }

    @Test func `text card in history has every applicable item`() {
        let menu = CardCommand.menu(for: [Self.card(1, .text)], in: .history, isSearchResult: false)

        #expect(menu == [
            [.paste, .pasteAsPlainText],
            [.copy, .copyAsPlainText],
            [.quickLook, .edit, .rename],
            [.addToBoard, .addToSequence],
            [.share],
            [.delete]
        ])
    }

    @Test func `file card on a board can be opened and removed`() {
        let menu = CardCommand.menu(for: [Self.card(1, .file)], in: .board(id: 1), isSearchResult: false)

        #expect(menu == [
            [.paste], [.copy], [.open, .openWith, .showInFinder], [.quickLook, .rename], [.addToBoard, .addToSequence],
            [.share],
            [.removeFromBoard]
        ])
    }

    @Test(arguments: [CardKind.text, .link, .image, .color, .unknown])
    func `open with hidden for text`(kind: CardKind) async {
        let menu = CardCommand.menu(for: [Self.card(1, kind)], in: .history, isSearchResult: false).joined()

        #expect(menu.contains(.openWith) == false)
        #expect(menu.contains(.showInFinder) == false)
        #expect(await OpenWithApplication.applications(for: Self.card(1, kind)).isEmpty)
    }

    @Test func `cards of unknown type cannot be shared`() {
        let unknown = [Self.card(1, .unknown), Self.card(2, .unknown)]

        #expect(CardCommand.menu(for: [unknown[0]], in: .history, isSearchResult: false).joined()
            .contains(.share) == false)
        #expect(CardCommand.menu(for: unknown, in: .history, isSearchResult: false).joined().contains(.share) == false)
        #expect(CardCommand.menu(
            for: [unknown[0], Self.card(3, .text)],
            in: .history,
            isSearchResult: false
        ).joined().contains(.share))
    }

    @Test func `search result can be shown in its list`() {
        let menu = CardCommand.menu(for: [Self.card(1, .text)], in: .history, isSearchResult: true)

        #expect(menu.contains([.quickLook, .showInList, .edit, .rename]))
        #expect(CardCommand.menu(
            for: [Self.card(1, .text), Self.card(2, .text)],
            in: .history,
            isSearchResult: true
        ).joined().contains(.showInList) == false)
    }

    @Test func `no cards means no menu`() {
        #expect(CardCommand.menu(for: [], in: .history, isSearchResult: false).isEmpty)
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
