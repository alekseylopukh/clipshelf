import DesignSystem
import Store
import SwiftUI

struct CardPreviewView: View {
    let card: CardSummary
    private let content: CardContent
    private let frame: PreviewFrame

    init(card: CardSummary, available: CGSize = PreviewSizeCalculator().defaultSize) {
        let content = CardContent(card)
        self.card = card
        self.content = content
        frame = PreviewSizeCalculator().frame(for: Self.kind(of: card, content: content), in: available)
    }

    var body: some View {
        Group {
            switch card.kind {
            case .text:
                TextCardPreview(card: card, isCodeLike: content.isCodeLike)
            case .link:
                FittingScrollView {
                    LinkCardPreview(card: card, content: content)
                }
            case .color:
                FittingScrollView {
                    ColorCardPreview(
                        swatch: content.swatch,
                        components: content.metadata.color.flatMap(ColorComponents.init(copiedText:))
                    )
                }
            case .image:
                ImageCardPreview(card: card)
            case .file:
                FileCardPreview(card: card)
            case .unknown:
                EmptyStateView(
                    Text("No Preview", comment: "Title of the preview of a card that Clipsy cannot show"),
                    systemImage: card.kind.symbolName,
                    description: Text(
                        "Clipsy can still paste this item.",
                        comment: "Body of a card whose type is unknown"
                    )
                )
            }
        }
        .frame(idealHeight: frame.height, maxHeight: frame.height)
        .safeAreaBar(edge: .bottom) {
            PreviewSourceBar(card: card, content: content)
        }
        .frame(width: frame.width)
        .frame(maxHeight: frame.maximumHeight)
    }

    private static func kind(of card: CardSummary, content: CardContent) -> PreviewKind {
        switch card.kind {
        case .text:
            return .text(isCodeLike: content.isCodeLike)
        case .link:
            return content.metadata.pixelWidth == nil ? .link : .linkWithImage
        case .color:
            return .color
        case .image:
            guard let width = content.metadata.pixelWidth, let height = content.metadata.pixelHeight else {
                return .image(pixelSize: nil)
            }
            return .image(pixelSize: CGSize(width: width, height: height))
        case .file:
            let count = content.metadata.fileNames?.count ?? 1
            return count > 1 ? .files(count: count) : .file
        case .unknown:
            return .unavailable
        }
    }
}

struct FittingScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                content
            }
        }
    }
}

private struct PreviewSourceBar: View {
    let card: CardSummary
    let content: CardContent

    var body: some View {
        HStack(spacing: DesignTokens.spacingMedium) {
            AppIconView(
                bundleID: card.sourceApp?.bundleID,
                fallbackSymbol: card.kind.symbolName,
                size: DesignTokens.previewSourceIconSize
            )
            if let name = card.sourceApp?.name {
                Text(verbatim: name)
            }
            TimelineView(.everyMinute) { context in
                // the timeline starts at the top of the minute, before a card copied seconds ago
                Text(max(context.date, card.displayDate), format: Date.AnchoredRelativeFormatStyle(
                    anchor: card.displayDate,
                    presentation: .named,
                    unitsStyle: .wide
                ))
            }
            CardFooter(kind: card.kind, content: content)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal)
        .frame(height: DesignTokens.previewSourceBarHeight)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Text") {
    CardPreviewView(card: CardSummary.previewCards[0])
}

#Preview("Link") {
    CardPreviewView(card: CardSummary.previewCards[2])
}

#Preview("Color") {
    CardPreviewView(card: CardSummary.previewCards[3])
}

#Preview("Unknown") {
    CardPreviewView(card: CardSummary.previewCards[4])
}
