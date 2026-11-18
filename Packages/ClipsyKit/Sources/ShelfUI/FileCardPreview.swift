import DesignSystem
import os
import Store
import SwiftUI

struct FileCardPreview: View {
    private enum Contents {
        case loading
        case file(URL)
        case missing(String)
        case files([URL])
        case unavailable
    }

    let card: CardSummary

    @State private var contents = Contents.loading
    @Environment(\.cardMediaLoader) private var loader

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    var body: some View {
        Group {
            switch contents {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .file(url):
                QuickLookView(url: url)
            case let .missing(name):
                EmptyStateView(
                    Text(
                        "File Not Found",
                        comment: "Title of the preview of a file card whose file was moved or deleted"
                    ),
                    systemImage: "questionmark.folder",
                    description: Text(verbatim: name)
                )
            case let .files(urls):
                List(urls, id: \.self) { url in
                    FilePreviewRow(url: url)
                }
                .scrollContentBackground(.hidden)
            case .unavailable:
                EmptyStateView(
                    Text("No Preview", comment: "Title of the preview of a card that Clipsy cannot show"),
                    systemImage: card.kind.symbolName
                )
            }
        }
        .task(id: card.id) {
            await loadContents()
        }
    }

    private func loadContents() async {
        guard let loader else { return }
        do {
            let urls = try await loader.fileURLs(of: card)
            guard urls.count == 1, let url = urls.first else {
                contents = urls.isEmpty ? .unavailable : .files(urls)
                return
            }
            contents = await loader.fileExists(at: url) ? .file(url) : .missing(url.lastPathComponent)
        } catch is CancellationError {
            return
        } catch {
            contents = .unavailable
            Self.logger.error("file preview failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}

private struct FilePreviewRow: View {
    let url: URL

    @State private var thumbnail: CGImage?
    @Environment(\.cardMediaLoader) private var loader
    @Environment(\.displayScale) private var displayScale

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    var body: some View {
        Label {
            Text(verbatim: url.lastPathComponent)
                .truncationMode(.middle)
        } icon: {
            Group {
                if let thumbnail {
                    Image(decorative: thumbnail, scale: displayScale)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "doc")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: DesignTokens.previewFileRowIconSize, height: DesignTokens.previewFileRowIconSize)
        }
        .lineLimit(1)
        .task(id: url) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let loader else { return }
        do {
            thumbnail = try await loader.files.thumbnail(
                of: url,
                pixelSize: DesignTokens.previewFileRowIconSize * displayScale
            )?.image
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("file thumbnail failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}
