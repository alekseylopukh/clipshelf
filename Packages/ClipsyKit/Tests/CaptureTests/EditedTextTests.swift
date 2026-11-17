import Foundation
import Store
import Testing
@testable import Capture

struct EditedTextTests {
    @Test func `edited text is hashed and counted like a copy`() async {
        let representations = [
            Representation(itemIndex: 0, uti: "public.rtf", data: Data("{\\rtf1 two words}".utf8)),
            Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data("two words\nnext".utf8))
        ]

        let card = await NewCard.editedText(representations)

        #expect(card.kind == .text)
        #expect(card.contentHash == contentHash(of: representations))
        #expect(card.representations == representations)
        #expect(card.previewText == "two words\nnext")
        #expect(card.metadata == #"{"characterCount":14,"lineCount":2,"wordCount":3}"#)
        #expect(card.sourceApp == NewCard.editorSourceApp)
    }

    @Test(arguments: [("https://example.com", CardKind.link), ("#FF8800", .color), ("plain words", .text)])
    func `edited text is classified like a copy`(text: String, kind: CardKind) async {
        let card = await NewCard.editedText([
            Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data(text.utf8))
        ])

        #expect(card.kind == kind)
    }

    @Test func `link edited to text becomes text`() async throws {
        let repository = try CardRepository(database: AppDatabase.temporary())
        let link = await NewCard.editedText([Self.plain("https://example.com")])
        let id = try await repository.record(link)

        try await repository.replaceContent(of: id, with: NewCard.editedText([Self.plain("hello world")]))

        let card = try #require(try await repository.cards(in: .history).first)
        #expect(card.id == id)
        #expect(card.kind == .text)
        #expect(card.metadata?.contains("url") == false)
    }

    @Test func `color edited to rgb stays a color`() async {
        let card = await NewCard.editedText([Self.plain("rgb(26, 43, 60)")])

        #expect(card.kind == .color)
        #expect(card.previewText == "rgb(26, 43, 60)")
    }

    private static func plain(_ text: String) -> Representation {
        Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data(text.utf8))
    }
}
