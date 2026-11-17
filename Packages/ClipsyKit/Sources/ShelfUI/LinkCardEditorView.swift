import Store
import SwiftUI

struct LinkCardEditorView: View {
    @Bindable var editor: LinkCardEditor
    let maxHeight: CGFloat

    var body: some View {
        CardFormSheet(
            title: "Edit Link",
            errorMessage: editor.errorMessage,
            canSave: editor.canSave,
            maxHeight: maxHeight,
            save: editor.save
        ) {
            TextField("URL", text: $editor.url, prompt: Text(verbatim: "https://"))
                .textContentType(.URL)
                .autocorrectionDisabled()
            TextField(
                "Title",
                text: $editor.title,
                prompt: editor.pageTitle.map { Text(verbatim: $0) } ?? Text("Optional")
            )
        }
    }
}

#Preview {
    let card = CardSummary(
        id: 1,
        kind: .link,
        metadata: #"{"url":"https://www.apple.com"}"#,
        createdAt: .now
    )
    LinkCardEditorView(editor: LinkCardEditor(card: card) { _ in } rename: { _ in }, maxHeight: 400)
}
