import DesignSystem
import os
import Store
import SwiftUI

struct LinkCardPreview: View {
    let card: CardSummary
    let content: CardContent

    @State private var image: CGImage?
    @Environment(\.cardMediaLoader) private var loader

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    private var hasImage: Bool {
        content.metadata.pixelWidth != nil
    }

    var body: some View {
        Group {
            if hasImage {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.fill.quaternary)
                        .overlay {
                            if let image {
                                Image(decorative: image, scale: 1)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                        }
                        .frame(height: DesignTokens.previewLinkImageHeight)
                        .clipped()
                        .accessibilityHidden(true)
                    LinkPreviewText(card: card, content: content)
                        .padding()
                }
            } else {
                HStack(alignment: .top, spacing: DesignTokens.spacingLarge) {
                    PlaceholderSymbol("link")
                        .accessibilityHidden(true)
                    LinkPreviewText(card: card, content: content)
                }
                .padding()
            }
        }
        .task(id: LinkImageRequest(hash: card.contentHash, hasImage: hasImage)) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let loader, let hash = card.contentHash, hasImage else {
            image = nil
            return
        }
        do {
            image = try await loader.linkImage(hash: hash, maxPixelSize: DesignTokens.thumbnailMaxPixelSize)
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("link image failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}

private struct LinkImageRequest: Hashable {
    let hash: String?
    let hasImage: Bool
}

private struct LinkPreviewText: View {
    let card: CardSummary
    let content: CardContent

    var body: some View {
        let title = card.title ?? content.metadata.pageTitle
        VStack(alignment: .leading, spacing: DesignTokens.spacingSmall) {
            if let heading = title ?? content.host {
                Text(verbatim: heading)
                    .font(.title2.weight(.semibold))
                    .lineLimit(3)
            }
            if title != nil, let host = content.host {
                Text(verbatim: host)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let url = content.metadata.url {
                Text(verbatim: url)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
