import DesignSystem
import Store
import SwiftUI

struct CardPreviewView: View {
    let card: CardSummary
    private let content: CardContent
    private let size: CGSize

    init(card: CardSummary, available: CGSize = PreviewSizeCalculator().defaultSize) {
        let content = CardContent(card)
        var imagePixelSize: CGSize?
        if card.kind == .image, let width = content.metadata.pixelWidth, let height = content.metadata.pixelHeight {
            imagePixelSize = CGSize(width: width, height: height)
        }
        self.card = card
        self.content = content
        size = PreviewSizeCalculator().size(in: available, imagePixelSize: imagePixelSize)
    }

    var body: some View {
        Group {
            switch card.kind {
            case .text:
                TextCardPreview(card: card, isCodeLike: content.isCodeLike)
            case .link:
                LinkCardPreview(
                    title: card.title ?? content.metadata.pageTitle,
                    host: content.host,
                    url: content.metadata.url
                )
            case .color:
                ColorCardPreview(
                    swatch: content.swatch,
                    components: content.metadata.color.flatMap(ColorComponents.init(copiedText:))
                )
            case .image:
                ImageCardPreview(card: card)
            case .file:
                FileCardPreview(card: card)
            case .unknown:
                ContentUnavailableView {
                    Label {
                        Text("No Preview", comment: "Title of the preview of a card that Clipsy cannot show")
                    } icon: {
                        Image(systemName: card.kind.symbolName)
                    }
                } description: {
                    Text("Clipsy can still paste this item.", comment: "Body of a card whose type is unknown")
                }
            }
        }
        .frame(width: size.width, height: size.height)
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
