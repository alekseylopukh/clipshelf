import SwiftUI

public struct InlineErrorLabel: View {
    let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
    }
}
