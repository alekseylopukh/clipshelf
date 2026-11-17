import DesignSystem
import SwiftUI

struct BoardEditorSheet: View {
    let isNew: Bool

    @Environment(BoardEditor.self) private var editor

    var body: some View {
        @Bindable var editor = editor
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $editor.name, prompt: Text("Untitled"))
                    LabeledContent("Color") {
                        BoardColorPicker(selection: $editor.color)
                    }
                } header: {
                    Text(isNew ? "New Board" : "Edit Board")
                        .font(.headline)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    editor.cancel()
                }
                .keyboardShortcut(.cancelAction)
                Button(isNew ? "Create" : "Save") {
                    Task {
                        await editor.save()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], DesignTokens.sheetPadding)
        }
        .frame(width: DesignTokens.boardSheetWidth)
    }
}
