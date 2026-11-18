import SwiftUI

public struct MediaCaption: View {
    let text: Text

    public init(_ text: Text) {
        self.text = text
    }

    public var body: some View {
        text
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .padding(DesignTokens.mediaCaptionInsets)
            .background(.ultraThinMaterial, in: .capsule)
    }
}
