import DesignSystem
import SwiftUI

struct CardRenameField: View {
    let title: String?
    let onCommit: (String) -> Void

    @State private var draft: String?

    var body: some View {
        TextField("Title", text: text, prompt: Text("Title"))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(width: DesignTokens.renameFieldWidth)
            .onSubmit {
                onCommit(draft ?? title ?? "")
            }
            .padding()
    }

    private var text: Binding<String> {
        Binding {
            draft ?? title ?? ""
        } set: { newValue in
            draft = newValue
        }
    }
}

#Preview("Renamed") {
    CardRenameField(title: "Invoice address") { _ in }
}

#Preview("Untitled") {
    CardRenameField(title: nil) { _ in }
}
