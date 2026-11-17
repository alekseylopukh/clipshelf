import Foundation
import Store
import Testing
@testable import ShelfUI

@MainActor
struct LinkCardEditorTests {
    private final class Calls {
        var replaced: [[Representation]] = []
        var renamed: [String] = []
        var error: (any Error)?
    }

    private let calls = Calls()

    private func editor(title: String? = nil) -> LinkCardEditor {
        let card = CardSummary(
            id: 1,
            kind: .link,
            title: title,
            metadata: #"{"pageTitle":"Example","url":"https://example.com"}"#,
            createdAt: .now
        )
        return LinkCardEditor(card: card) { [calls] in
            if let error = calls.error {
                throw error
            }
            calls.replaced.append($0)
        } rename: { [calls] in
            calls.renamed.append($0)
        }
    }

    @Test func `opens with the url and custom title`() {
        let editor = editor(title: "Docs")

        #expect(editor.url == "https://example.com")
        #expect(editor.title == "Docs")
        #expect(editor.pageTitle == "Example")
    }

    @Test func `saving without changes writes nothing`() async {
        #expect(await editor().save())

        #expect(calls.replaced.isEmpty)
        #expect(calls.renamed.isEmpty)
    }

    @Test func `edited url is saved as trimmed plain text`() async {
        let editor = editor()
        editor.url = "  hello world \n"

        #expect(await editor.save())

        #expect(calls.replaced == [[Representation(
            itemIndex: 0,
            uti: "public.utf8-plain-text",
            data: Data("hello world".utf8)
        )]])
        #expect(calls.renamed.isEmpty)
    }

    @Test func `edited title renames without replacing content`() async {
        let editor = editor(title: "Docs")
        editor.title = ""

        #expect(await editor.save())

        #expect(calls.replaced.isEmpty)
        #expect(calls.renamed == [""])
    }

    @Test func `duplicate url shows an inline error and editing clears it`() async {
        let editor = editor()
        calls.error = CardEditError.duplicateContent
        editor.url = "https://example.org"

        #expect(await editor.save() == false)

        #expect(editor.errorMessage == CardEditorMessage.text(for: CardEditError.duplicateContent))
        editor.url = "https://example.net"
        #expect(editor.errorMessage == nil)
    }

    @Test func `blank url cannot be saved`() async {
        let editor = editor()
        editor.url = "   "

        #expect(editor.canSave == false)
        #expect(await editor.save() == false)
        #expect(calls.replaced.isEmpty)
    }
}
