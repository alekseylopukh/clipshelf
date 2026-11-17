import CoreGraphics
import Foundation
import os
import Store

@MainActor
public final class LinkPreviewFetcher {
    private static let webSchemes: Set<String> = ["http", "https"]

    private let provider: any LinkMetadataProviding
    private let repository: CardRepository
    private let thumbnails: ThumbnailCache
    private let maxPixelSize: Int
    private let isEnabled: () -> Bool
    private let cardIDs: AsyncStream<Int64>
    private let continuation: AsyncStream<Int64>.Continuation
    private let logger = Logger(subsystem: "app.gonar.clipsy", category: "LinkPreviews")

    public init(
        provider: any LinkMetadataProviding = LinkPresentationProvider(),
        repository: CardRepository,
        thumbnails: ThumbnailCache,
        maxPixelSize: Int,
        isEnabled: @escaping () -> Bool
    ) {
        self.provider = provider
        self.repository = repository
        self.thumbnails = thumbnails
        self.maxPixelSize = maxPixelSize
        self.isEnabled = isEnabled
        (cardIDs, continuation) = AsyncStream.makeStream()
    }

    deinit {
        continuation.finish()
    }

    public func submit(_ cardID: Int64) {
        continuation.yield(cardID)
    }

    /// fetches one preview at a time until the calling task is cancelled, then throws `CancellationError`
    public func run() async throws {
        for await cardID in cardIDs {
            try await fetchPreview(for: cardID)
        }
        try Task.checkCancellation()
    }

    func fetchPreview(for cardID: Int64) async throws {
        guard isEnabled() else { return }
        do {
            guard let link = try await repository.linkAwaitingPreview(card: cardID),
                  let scheme = link.url.scheme?.lowercased(), Self.webSchemes.contains(scheme)
            else { return }
            let preview = try await provider.preview(for: link.url)
            let title = preview.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            var image: CGImage?
            if let data = preview.imageData {
                image = try await thumbnails.store(data, forHash: link.contentHash, maxPixelSize: maxPixelSize)
            }
            let storedTitle = title?.isEmpty == false ? title : nil
            guard storedTitle != nil || image != nil else { return }
            try await repository.saveLinkPreview(
                card: cardID,
                title: storedTitle,
                imageSize: image.map { ($0.width, $0.height) }
            )
        } catch let error as CancellationError {
            throw error
        } catch {
            logger.error("link preview failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}
