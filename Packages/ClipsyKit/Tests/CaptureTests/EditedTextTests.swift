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
}
