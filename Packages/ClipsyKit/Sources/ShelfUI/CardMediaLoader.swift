import AppKit
import Media
import Store
import SwiftUI
import UniformTypeIdentifiers

struct CardMediaLoader: Sendable {
    struct FileIcon: Identifiable, Sendable {
        let id: URL
        let position: Int
        let image: CGImage
    }

    static let maximumFileIcons = 3

    let representations: @Sendable (Int64) async throws -> [Representation]
    let thumbnails: ThumbnailCache

    @concurrent
    func thumbnail(of card: CardSummary, hash: String, maxPixelSize: Int) async throws -> CGImage? {
        try await thumbnails.thumbnail(forHash: hash, maxPixelSize: maxPixelSize) {
            try await representations(card.id)
                .filter { UTType($0.uti).map { $0.conforms(to: .image) || $0.conforms(to: .pdf) } ?? false }
                .map(\.data)
        }
    }

    /// link images are written by the link preview fetcher, never made here
    @concurrent
    func linkImage(hash: String, maxPixelSize: Int) async throws -> CGImage? {
        try await thumbnails.thumbnail(forHash: hash, maxPixelSize: maxPixelSize) { [] }
    }

    @concurrent
    func fileIcons(of card: CardSummary, pixelSize: CGFloat) async throws -> [FileIcon] {
        let urls = try await card.openableURLs(in: representations(card.id)).prefix(Self.maximumFileIcons)
        try Task.checkCancellation()
        return urls.enumerated().compactMap { position, url in
            var rect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
            let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
            return icon.cgImage(forProposedRect: &rect, context: nil, hints: nil).map {
                FileIcon(id: url, position: position, image: $0)
            }
        }
    }
}

extension EnvironmentValues {
    @Entry var cardMediaLoader: CardMediaLoader?
}
