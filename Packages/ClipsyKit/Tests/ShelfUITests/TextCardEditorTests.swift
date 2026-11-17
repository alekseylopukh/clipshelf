import AppKit
import Store
import Testing
@testable import ShelfUI

@MainActor
struct TextCardEditorTests {
    private static let plain = "public.utf8-plain-text"
    private static let rtf = "public.rtf"

    private final class Saves {
        var calls: [(TextCardEditor.Target, [Representation])] = []
        var error: (any Error)?
    }

    private let saves = Saves()

    private func editor(_ target: TextCardEditor.Target, text: String? = nil) -> (TextCardEditor, NSTextView) {
        let representations = text.map { [Representation(itemIndex: 0, uti: Self.plain, data: Data($0.utf8))] } ?? []
        let editor = TextCardEditor(target: target, representations: representations) { [saves] target, text in
            if let error = saves.error {
                throw error
            }
            saves.calls.append((target, text))
        }
        let textView = NSTextView()
        textView.textStorage?.setAttributedString(editor.initialText)
        editor.attach(textView)
        return (editor, textView)
    }

    @Test func `new card on a board tab is saved to that board`() async {
        let (editor, textView) = editor(.new(.board(id: 5)))
        textView.string = "Hello"
        editor.textDidChange()

        #expect(await editor.save())

        #expect(saves.calls.map(\.0) == [.new(.board(id: 5))])
        #expect(saves.calls.first?.1 == [Representation(itemIndex: 0, uti: Self.plain, data: Data("Hello".utf8))])
    }

    @Test func `plain text stays plain and styled text gains rtf`() async throws {
        let (editor, textView) = editor(.card(1), text: "Hello world")
        #expect(await editor.save())
        #expect(saves.calls.last?.1.map(\.uti) == [Self.plain])

        textView.setSelectedRange(NSRange(location: 0, length: 5))
        editor.setStyle(.bold, applied: true)
        #expect(await editor.save())

        let representations = try #require(saves.calls.last?.1)
        #expect(representations.map(\.uti) == [Self.rtf, Self.plain])
        let saved = try #require(NSAttributedString(rtf: representations[0].data, documentAttributes: nil))
        #expect(saved.string == "Hello world")
        #expect(TextStyle.bold.isApplied(in: saved.attributes(at: 0, effectiveRange: nil)))
        #expect(TextStyle.bold.isApplied(in: saved.attributes(at: 6, effectiveRange: nil)) == false)
    }

    @Test func `blank text cannot be saved`() async {
        let (editor, _) = editor(.new(.history))

        #expect(editor.canSave == false)
        #expect(await editor.save() == false)
        #expect(saves.calls.isEmpty)
    }

    @Test func `duplicate content shows an inline error until the text changes`() async {
        let (editor, textView) = editor(.card(1), text: "Hello")
        saves.error = CardEditError.duplicateContent

        #expect(await editor.save() == false)
        #expect(editor.errorMessage != nil)

        textView.string = "Hello again"
        editor.textDidChange()
        #expect(editor.errorMessage == nil)
    }

    @Test func `counts follow the text`() {
        let (editor, textView) = editor(.card(1), text: "one")
        #expect(editor.counts == TextCounts("one"))

        textView.string = "one two\nthree"
        editor.textDidChange()

        #expect(editor.counts.characters == 13)
        #expect(editor.counts.words == 3)
        #expect(editor.counts.lines == 2)
    }

    @Test(arguments: TextStyle.allCases)
    func `style toggles on the selection and back`(style: TextStyle) {
        let (editor, textView) = editor(.card(1), text: "Hello world")
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        editor.setStyle(style, applied: true)
        #expect(editor.activeStyles == [style])
        textView.setSelectedRange(NSRange(location: 0, length: 11))
        editor.selectionDidChange()
        #expect(editor.activeStyles.isEmpty)

        editor.setStyle(style, applied: false)
        let text = textView.attributedString()
        #expect(TextCardContent.hasStyles(text) == false)
    }

    @Test func `style without a selection applies to typing`() {
        let (editor, textView) = editor(.new(.history))

        editor.setStyle(.italic, applied: true)

        #expect(editor.activeStyles == [.italic])
        #expect(TextStyle.italic.isApplied(in: textView.typingAttributes))
    }

    @Test func `rich content loads from rtf`() throws {
        let styled = NSAttributedString(string: "Bold", attributes: [
            .font: NSFontManager.shared.convert(TextCardEditor.font, toHaveTrait: .boldFontMask)
        ])
        let data = try styled.data(
            from: NSRange(location: 0, length: styled.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        let representations = [
            Representation(itemIndex: 0, uti: Self.rtf, data: data),
            Representation(itemIndex: 0, uti: Self.plain, data: Data("Bold".utf8))
        ]

        let loaded = TextCardContent.attributedString(from: representations, font: TextCardEditor.font)

        #expect(loaded.string == "Bold")
        #expect(TextStyle.bold.isApplied(in: loaded.attributes(at: 0, effectiveRange: nil)))
        #expect(TextCardContent.isRich(representations))
    }
}
