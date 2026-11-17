import AppKit
import Media
import Store
import SwiftUI
import UniformTypeIdentifiers

struct CardMediaLoader: Sendable {
    struct FileThumbnail: Identifiable, Sendable {
        let id: URL
        let position: Int
        let image: CGImage
    }

    static let maximumStackedFiles = 3

    let representations: @Sendable (Int64) async throws -> [Representation]
    let thumbnails: ThumbnailCache
    let files = FileThumbnailer()

    @concurrent
    func thumbnail(of card: CardSummary, hash: String, maxPixelSize: Int) async throws -> CGImage? {
        try await thumbnails.thumbnail(forHash: hash, maxPixelSize: maxPixelSize) {
            try await imageCandidates(of: card)
        }
    }

    /// link images are written by the link preview fetcher, never made here
    @concurrent
    func linkImage(hash: String, maxPixelSize: Int) async throws -> CGImage? {
        try await thumbnails.thumbnail(forHash: hash, maxPixelSize: maxPixelSize) { [] }
    }

    @concurrent
    func image(of card: CardSummary, maxPixelSize: Int) async throws -> CGImage? {
        for data in try await imageCandidates(of: card) {
            try Task.checkCancellation()
            if let image = ThumbnailCache.downsample(data, maxPixelSize: maxPixelSize) {
                return image
            }
        }
        return nil
    }

    @concurrent
    func fileURLs(of card: CardSummary) async throws -> [URL] {
        try await card.openableURLs(in: representations(card.id))
    }

    @concurrent
    func fileExists(at url: URL) async -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    @concurrent
    func fileThumbnails(of card: CardSummary, pixelSize: CGFloat) async throws -> [FileThumbnail] {
        var thumbnails: [FileThumbnail] = []
        for (position, url) in try await fileURLs(of: card).prefix(Self.maximumStackedFiles).enumerated() {
            if let thumbnail = try await files.thumbnail(of: url, pixelSize: pixelSize) {
                thumbnails.append(FileThumbnail(id: url, position: position, image: thumbnail.image))
            }
        }
        return thumbnails
    }

    private func imageCandidates(of card: CardSummary) async throws -> [Data] {
        try await representations(card.id)
            .filter { UTType($0.uti).map { $0.conforms(to: .image) || $0.conforms(to: .pdf) } ?? false }
            .map(\.data)
    }
}

extension EnvironmentValues {
    @Entry var cardMediaLoader: CardMediaLoader?
}
