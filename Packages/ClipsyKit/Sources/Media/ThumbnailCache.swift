import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ThumbnailCache: Sendable {
    public enum Failure: Error {
        case encodingFailed
    }

    let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `candidates` runs only on a cache miss; the first decodable candidate becomes the thumbnail
    @concurrent
    public func thumbnail(
        forHash hash: String,
        maxPixelSize: Int,
        candidates: @Sendable () async throws -> [Data]
    ) async throws -> CGImage? {
        let url = fileURL(for: hash)
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let cached = CGImageSourceCreateImageAtIndex(source, 0, nil)
        {
            return cached
        }
        for data in try await candidates() {
            try Task.checkCancellation()
            guard let image = Self.downsample(data, maxPixelSize: maxPixelSize) else { continue }
            try write(image, to: url)
            return image
        }
        return nil
    }

    /// returns nil when `data` is not a decodable image
    @concurrent
    public func store(_ data: Data, forHash hash: String, maxPixelSize: Int) async throws -> CGImage? {
        guard let image = Self.downsample(data, maxPixelSize: maxPixelSize) else { return nil }
        try write(image, to: fileURL(for: hash))
        return image
    }

    func fileURL(for hash: String) -> URL {
        directory.appending(path: "\(hash).png", directoryHint: .notDirectory)
    }

    private static func downsample(_ data: Data, maxPixelSize: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    private func write(_ image: CGImage, to url: URL) throws {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw Failure.encodingFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.encodingFailed }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try (data as Data).write(to: url, options: .atomic)
    }
}
