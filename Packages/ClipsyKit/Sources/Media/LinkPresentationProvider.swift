import Foundation
import LinkPresentation
import UniformTypeIdentifiers

public struct LinkPresentationProvider: LinkMetadataProviding {
    public init() {}

    public func preview(for url: URL) async throws -> LinkPreview {
        let metadata = try await LPMetadataProvider().startFetchingMetadata(for: url)
        let title = metadata.title
        guard let imageProvider = metadata.imageProvider else { return LinkPreview(title: title, imageData: nil) }
        return try await LinkPreview(title: title, imageData: Self.imageData(from: imageProvider))
    }

    @concurrent
    private static func imageData(from provider: NSItemProvider) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadDataRepresentation(for: .image) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }
    }
}
