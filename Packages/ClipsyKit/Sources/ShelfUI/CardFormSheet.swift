import DesignSystem
import SwiftUI

struct CardFormSheet<Fields: View>: View {
    let title: LocalizedStringKey
    let errorMessage: String?
    let canSave: Bool
    let maxHeight: CGFloat
    let save: () async -> Bool
    @ViewBuilder let fields: Fields

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .vertical) {
                CardForm(title: title, fields: fields)
                    .scrollDisabled(true)
                    .fixedSize(horizontal: false, vertical: true)
                CardForm(title: title, fields: fields)
            }
            SheetButtonBar(errorMessage: errorMessage) {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    Task {
                        if await save() {
                            dismiss()
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding([.horizontal, .bottom], DesignTokens.sheetPadding)
        }
        .frame(width: DesignTokens.cardFormSheetWidth)
        .frame(maxHeight: maxHeight)
    }
}

private struct CardForm<Fields: View>: View {
    let title: LocalizedStringKey
    let fields: Fields

    var body: some View {
        Form {
            Section {
                fields
            } header: {
                SheetHeader(Text(title))
            }
        }
        .formStyle(.grouped)
    }
}
