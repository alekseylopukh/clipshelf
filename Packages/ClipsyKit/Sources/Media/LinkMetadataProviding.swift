import Foundation

@MainActor
public protocol LinkMetadataProviding {
    func preview(for url: URL) async throws -> LinkPreview
}
