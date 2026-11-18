import SwiftUI

public struct SheetButtonBar<Buttons: View>: View {
    let errorMessage: String?
    let buttons: Buttons

    public init(errorMessage: String? = nil, @ViewBuilder buttons: () -> Buttons) {
        self.errorMessage = errorMessage
        self.buttons = buttons()
    }

    public var body: some View {
        HStack {
            if let errorMessage {
                InlineErrorLabel(errorMessage)
            }
            Spacer()
            buttons
        }
    }
}
