import DesignSystem
import os
import Store
import SwiftUI

struct TextCardPreview: View {
    let card: CardSummary
    let isCodeLike: Bool

    @State private var text: Text?
    @Environment(\.richTextLoader) private var loader
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    var body: some View {
        FittingScrollView {
            (text ?? Text(verbatim: card.preview ?? ""))
                .font(isCodeLike ? .body.monospaced() : .title3)
                .lineSpacing(DesignTokens.previewTextLineSpacing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding()
                .frame(minHeight: DesignTokens.previewTextMinimumHeight, alignment: .top)
        }
        .background(Color(nsColor: DesignTokens.cardFill))
        .task(id: RichTextRequest(cardID: card.id, colorScheme: colorScheme, contrast: contrast)) {
            await loadText()
        }
    }

    private func loadText() async {
        guard let loader,
              let background = RichTextPreview.cardFillLuminance(colorScheme: colorScheme, contrast: contrast)
        else { return }
        do {
            let length = DesignTokens.previewTextMaximumLength
            if let rich = try await loader.preview(
                of: card.id,
                bodySize: NSFont.preferredFont(forTextStyle: isCodeLike ? .body : .title3).pointSize,
                background: background,
                maximumLength: length
            ) {
                text = Text(rich)
            } else if let plain = try await loader.plainText(of: card.id, maximumLength: length) {
                text = Text(verbatim: plain)
            }
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("text preview failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}
