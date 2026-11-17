import AppKit
import Store
import SwiftUI

struct ColorCardEditorView: View {
    let editor: ColorCardEditor
    let maxHeight: CGFloat

    var body: some View {
        CardFormSheet(
            title: "Edit Color",
            errorMessage: editor.errorMessage,
            canSave: editor.canSave,
            maxHeight: maxHeight,
            save: editor.save
        ) {
            ColorPicker(
                "Color",
                selection: Binding { editor.cgColor } set: { editor.setColor($0) },
                supportsOpacity: false
            )
            Picker("Format", selection: Binding { editor.format } set: { editor.setFormat($0) }) {
                ForEach(CardColor.Format.allCases, id: \.self) { format in
                    Text(format.title)
                }
            }
            .pickerStyle(.segmented)
            TextField(
                "Value",
                text: Binding { editor.value } set: { editor.setValue($0) },
                prompt: Text(verbatim: "#1A2B3C")
            )
            .autocorrectionDisabled()
        }
        .onAppear {
            // the app stays inactive behind the non-activating Shelf, which would hide the color panel
            NSColorPanel.shared.hidesOnDeactivate = false
        }
        .onDisappear {
            if NSColorPanel.sharedColorPanelExists {
                NSColorPanel.shared.close()
            }
        }
    }
}

private extension CardColor.Format {
    var title: String {
        switch self {
        case .hex:
            String(localized: "Hex", comment: "Color format picker option for values such as #1A2B3C")
        case .rgb:
            String(localized: "RGB", comment: "Color format picker option for values such as rgb(26, 43, 60)")
        }
    }
}

#Preview {
    let card = CardSummary(id: 1, kind: .color, metadata: ##"{"color":"#FF8000"}"##, createdAt: .now)
    ColorCardEditorView(editor: ColorCardEditor(card: card) { _ in }, maxHeight: 400)
}
