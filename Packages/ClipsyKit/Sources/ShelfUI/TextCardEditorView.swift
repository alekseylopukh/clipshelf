import DesignSystem
import Store
import SwiftUI

struct TextCardEditorView: View {
    let editor: TextCardEditor
    let maxHeight: CGFloat

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLarge) {
            TextStyleControls(editor: editor)
            RichTextView(editor: editor)
                .clipShape(.rect(cornerRadius: DesignTokens.textEditorCornerRadius))
                .background(.background, in: .rect(cornerRadius: DesignTokens.textEditorCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.textEditorCornerRadius)
                        .strokeBorder(.separator)
                }
            TextCountsView(counts: editor.counts)
            SheetButtonBar(errorMessage: editor.errorMessage) {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    Task {
                        if await editor.save() {
                            dismiss()
                        }
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!editor.canSave)
            }
        }
        .padding(DesignTokens.sheetPadding)
        .frame(width: DesignTokens.textEditorWidth)
        .frame(height: min(DesignTokens.textEditorHeight, maxHeight))
    }
}

private struct TextStyleControls: View {
    let editor: TextCardEditor

    var body: some View {
        ControlGroup {
            ForEach(TextStyle.allCases, id: \.self) { style in
                Toggle(style.title, systemImage: style.systemImage, isOn: Binding {
                    editor.activeStyles.contains(style)
                } set: { isOn in
                    editor.setStyle(style, applied: isOn)
                })
                .keyboardShortcut(style.shortcut)
            }
        }
        .toggleStyle(.button)
        .labelStyle(.iconOnly)
        .fixedSize()
    }
}

private struct TextCountsView: View {
    let counts: TextCounts

    var body: some View {
        HStack(spacing: DesignTokens.spacingLarge) {
            Text("\(counts.characters) characters")
            Text("\(counts.words) words")
            Text("\(counts.lines) lines")
        }
        .metadataStyle()
    }
}

#Preview("New") {
    TextCardEditorView(editor: TextCardEditor(target: .new(.history)) { _, _ in }, maxHeight: 400)
}

#Preview("Edit") {
    let representations = [Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data("Hello there".utf8))]
    TextCardEditorView(
        editor: TextCardEditor(target: .card(1), representations: representations) { _, _ in },
        maxHeight: 400
    )
}
