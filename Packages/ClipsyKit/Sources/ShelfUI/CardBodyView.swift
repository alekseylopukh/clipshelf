import DesignSystem
import os
import Store
import SwiftUI

struct CardBodyView: View {
    let card: CardSummary
    let content: CardContent

    var body: some View {
        Group {
            switch card.kind {
            case .text:
                TextCardBody(card: card, isCodeLike: content.isCodeLike)
            case .link:
                SymbolCardBody(symbol: card.kind.symbolName, caption: content.host.map { Text(verbatim: $0) })
            case .color:
                ColorCardBody(value: content.metadata.color, swatch: content.swatch)
            case .image, .file:
                SymbolCardBody(symbol: card.kind.symbolName, caption: nil)
            case .unknown:
                SymbolCardBody(
                    symbol: card.kind.symbolName,
                    caption: Text("Clipsy can still paste this item.", comment: "Body of a card whose type is unknown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(.rect(cornerRadius: DesignTokens.cardInnerCornerRadius))
    }
}

private struct TextCardBody: View {
    let card: CardSummary
    let isCodeLike: Bool

    @State private var richText: AttributedString?
    @Environment(\.richTextLoader) private var loader
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    var body: some View {
        Group {
            if let richText {
                Text(richText)
                    .font(.body)
            } else {
                Text(verbatim: card.preview ?? "")
                    .font(isCodeLike ? .body.monospaced() : .body)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .fadeTruncation()
        .task(id: RichTextRequest(cardID: card.id, colorScheme: colorScheme, contrast: contrast)) {
            await loadRichText()
        }
    }

    private func loadRichText() async {
        guard let loader else { return }
        let name: NSAppearance.Name = switch (colorScheme, contrast) {
        case (.dark, .increased): .accessibilityHighContrastDarkAqua
        case (.dark, _): .darkAqua
        case (_, .increased): .accessibilityHighContrastAqua
        default: .aqua
        }
        let appearance = NSAppearance(named: name)
        var background: RichTextPreview.Luminance?
        appearance?.performAsCurrentDrawingAppearance {
            background = RichTextPreview.Luminance(DesignTokens.cardFill)
        }
        guard let background else { return }
        do {
            richText = try await loader.preview(
                of: card.id,
                bodySize: NSFont.preferredFont(forTextStyle: .body).pointSize,
                background: background
            )
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("rich text preview failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}

private struct RichTextRequest: Hashable {
    let cardID: Int64
    let colorScheme: ColorScheme
    let contrast: ColorSchemeContrast
}

private struct SymbolCardBody: View {
    let symbol: String
    let caption: Text?

    var body: some View {
        VStack(spacing: DesignTokens.spacingMedium) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            if let caption {
                caption
                    .font(.callout.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ColorCardBody: View {
    let value: String?
    let swatch: Color?

    var body: some View {
        if let swatch {
            Rectangle()
                .fill(swatch)
                .overlay {
                    if let value {
                        Text(verbatim: value)
                            .font(.callout.monospaced())
                            .padding(DesignTokens.colorValueInsets)
                            .glassEffect(.regular, in: .capsule)
                    }
                }
        } else {
            SymbolCardBody(symbol: CardKind.color.symbolName, caption: value.map { Text(verbatim: $0) })
        }
    }
}
