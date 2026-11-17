import AppKit
import Store
import SwiftUI

struct RichTextLoader: Sendable {
    let representations: @Sendable (Int64) async throws -> [Representation]

    @concurrent
    func preview(
        of cardID: Int64,
        bodySize: CGFloat,
        background: RichTextPreview.Luminance,
        maximumLength: Int = RichTextPreview.maximumLength
    ) async throws -> AttributedString? {
        let loaded = try await representations(cardID)
        try Task.checkCancellation()
        return RichTextPreview.attributedString(
            from: loaded,
            bodySize: bodySize,
            background: background,
            maximumLength: maximumLength
        )
    }

    @concurrent
    func plainText(of cardID: Int64, maximumLength: Int) async throws -> String? {
        let loaded = try await representations(cardID)
        guard let data = loaded.first(where: { $0.uti == NSPasteboard.PasteboardType.string.rawValue })?.data,
              let text = String(bytes: data, encoding: .utf8)
        else { return nil }
        return String(text.prefix(maximumLength))
    }
}

extension EnvironmentValues {
    @Entry var richTextLoader: RichTextLoader?
}
