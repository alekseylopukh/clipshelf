import SwiftUI

public struct FormFootnote: View {
    let text: Text

    public init(_ text: Text) {
        self.text = text
    }

    public var body: some View {
        text
            .foregroundStyle(.secondary)
    }
}
