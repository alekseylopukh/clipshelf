import DesignSystem
import os
import Store
import SwiftUI

struct CardBodyView: View {
    let card: CardSummary
    let content: CardContent
    let highlightedPreview: AttributedString?

    var body: some View {
        Group {
            switch card.kind {
            case .text:
                TextCardBody(card: card, isCodeLike: content.isCodeLike, highlightedPreview: highlightedPreview)
            case .link:
                LinkCardBody(card: card, content: content)
            case .color:
                ColorCardBody(value: content.metadata.color, swatch: content.swatch)
            case .image:
                ImageCardBody(card: card)
            case .file:
                FileCardBody(card: card, fileCount: content.metadata.fileNames?.count ?? 1)
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
        .clipShape(.cardInner)
    }
}

private struct TextCardBody: View {
    let card: CardSummary
    let isCodeLike: Bool
    let highlightedPreview: AttributedString?

    @State private var richText: AttributedString?
    @Environment(\.richTextLoader) private var loader
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    var body: some View {
        Color.clear
            .overlay(alignment: .topLeading) {
                Group {
                    if let highlightedPreview {
                        Text(highlightedPreview)
                            .font(isCodeLike ? .body.monospaced() : .body)
                    } else if let richText {
                        Text(richText)
                            .font(.body)
                    } else {
                        Text(verbatim: card.preview ?? "")
                            .font(isCodeLike ? .body.monospaced() : .body)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .fadeTruncation()
            .task(id: RichTextRequest(cardID: card.id, colorScheme: colorScheme, contrast: contrast)) {
                await loadRichText()
            }
    }

    private func loadRichText() async {
        guard let loader,
              let background = RichTextPreview.cardFillLuminance(colorScheme: colorScheme, contrast: contrast)
        else { return }
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

struct RichTextRequest: Hashable {
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

private struct LinkCardBody: View {
    let card: CardSummary
    let content: CardContent

    @State private var image: CGImage?
    @Environment(\.cardMediaLoader) private var loader

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    var body: some View {
        Group {
            if let image {
                VStack(alignment: .leading, spacing: DesignTokens.spacingMedium) {
                    Color.clear
                        .overlay {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipShape(.cardInner)
                    if let title = content.metadata.pageTitle {
                        Text(verbatim: title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(2)
                    }
                }
            } else {
                SymbolCardBody(
                    symbol: card.kind.symbolName,
                    caption: (content.metadata.pageTitle ?? content.host).map { Text(verbatim: $0) }
                )
            }
        }
        .task(id: LinkImageRequest(hash: card.contentHash, hasImage: content.metadata.pixelWidth != nil)) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let loader, let hash = card.contentHash, content.metadata.pixelWidth != nil else {
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

private struct ImageCardBody: View {
    let card: CardSummary

    @State private var thumbnail: CGImage?
    @Environment(\.cardMediaLoader) private var loader

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    var body: some View {
        Group {
            if let thumbnail {
                Image(decorative: thumbnail, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background {
                        if thumbnail.hasAlpha {
                            Checkerboard()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.fill.quaternary)
            } else {
                SymbolCardBody(symbol: card.kind.symbolName, caption: nil)
            }
        }
        .task(id: card.contentHash) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let loader, let hash = card.contentHash else { return }
        do {
            thumbnail = try await loader.thumbnail(
                of: card,
                hash: hash,
                maxPixelSize: DesignTokens.thumbnailMaxPixelSize
            )
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("thumbnail failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}

private struct FileCardBody: View {
    let card: CardSummary
    let fileCount: Int

    @State private var thumbnails: [CardMediaLoader.FileThumbnail] = []
    @Environment(\.cardMediaLoader) private var loader
    @Environment(\.displayScale) private var displayScale

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    private var iconSize: CGFloat {
        fileCount > 1 ? DesignTokens.fileStackIconSize : DesignTokens.fileIconSize
    }

    var body: some View {
        Group {
            if thumbnails.isEmpty {
                SymbolCardBody(symbol: fileCount > 1 ? "doc.on.doc" : card.kind.symbolName, caption: nil)
            } else {
                ZStack {
                    ForEach(thumbnails.reversed()) { thumbnail in
                        FanPosition(index: thumbnail.position, count: thumbnails.count) {
                            Image(decorative: thumbnail.image, scale: displayScale)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: iconSize, height: iconSize)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: FileIconRequest(cardID: card.id, displayScale: displayScale)) {
            await loadThumbnails()
        }
    }

    private func loadThumbnails() async {
        guard let loader else { return }
        do {
            thumbnails = try await loader.fileThumbnails(of: card, pixelSize: iconSize * displayScale)
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("file thumbnails failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}

private struct FileIconRequest: Hashable {
    let cardID: Int64
    let displayScale: CGFloat
}

private struct FanPosition<Content: View>: View {
    let index: Int
    let count: Int
    @ViewBuilder let content: Content

    var body: some View {
        let step = Double(index) - Double(count - 1) / 2
        content
            .rotationEffect(.degrees(step * DesignTokens.fileStackAngle))
            .offset(x: step * DesignTokens.fileStackOffset)
    }
}

extension CGImage {
    var hasAlpha: Bool {
        [.none, .noneSkipFirst, .noneSkipLast].contains(alphaInfo) == false
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
