import Store
import SwiftUI

struct RichTextLoader: Sendable {
    let representations: @Sendable (Int64) async throws -> [Representation]

    @concurrent
    func preview(
        of cardID: Int64,
        bodySize: CGFloat,
        background: RichTextPreview.Luminance
    ) async throws -> AttributedString? {
        let loaded = try await representations(cardID)
        try Task.checkCancellation()
        return RichTextPreview.attributedString(from: loaded, bodySize: bodySize, background: background)
    }
}

extension EnvironmentValues {
    @Entry var richTextLoader: RichTextLoader?
}
