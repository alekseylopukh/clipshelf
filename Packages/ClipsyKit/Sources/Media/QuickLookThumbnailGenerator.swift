import CoreGraphics
import Foundation
import QuickLookThumbnailing

public struct QuickLookThumbnailGenerator: FileThumbnailGenerating {
    public init() {}

    public func thumbnail(of url: URL, pixelSize: CGFloat) async throws -> CGImage {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: pixelSize, height: pixelSize),
            scale: 1,
            representationTypes: .thumbnail
        )
        request.iconMode = true
        return try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).cgImage
    }
}
