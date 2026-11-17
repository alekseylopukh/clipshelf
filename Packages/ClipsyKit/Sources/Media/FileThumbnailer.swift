import AppKit
import UniformTypeIdentifiers

public final class FileThumbnailer: Sendable {
    public struct Thumbnail: Sendable {
        public let image: CGImage
        public let isFileIcon: Bool
    }

    private final class Entry: Sendable {
        let thumbnail: Thumbnail

        init(_ thumbnail: Thumbnail) {
            self.thumbnail = thumbnail
        }
    }

    private static let cacheCountLimit = 200

    private let generator: any FileThumbnailGenerating
    /// NSCache is thread-safe, it only lacks the Sendable annotation
    private nonisolated(unsafe) let cache = NSCache<NSString, Entry>()

    public init(generator: any FileThumbnailGenerating = QuickLookThumbnailGenerator()) {
        self.generator = generator
        cache.countLimit = Self.cacheCountLimit
    }

    @concurrent
    public func thumbnail(of url: URL, pixelSize: CGFloat) async throws -> Thumbnail? {
        guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        else {
            return Self.icon(for: url, exists: false, pixelSize: pixelSize)
        }
        let key =
            "\(pixelSize)|\(modified.timeIntervalSinceReferenceDate)|\(url.path(percentEncoded: false))" as NSString
        if let entry = cache.object(forKey: key) {
            return entry.thumbnail
        }
        let thumbnail: Thumbnail?
        do {
            thumbnail = try await Thumbnail(
                image: generator.thumbnail(of: url, pixelSize: pixelSize),
                isFileIcon: false
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            thumbnail = Self.icon(for: url, exists: true, pixelSize: pixelSize)
        }
        if let thumbnail {
            cache.setObject(Entry(thumbnail), forKey: key)
        }
        return thumbnail
    }

    private static func icon(for url: URL, exists: Bool, pixelSize: CGFloat) -> Thumbnail? {
        let icon = exists
            ? NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
            : NSWorkspace.shared.icon(for: UTType(filenameExtension: url.pathExtension) ?? .data)
        var rect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        return icon.cgImage(forProposedRect: &rect, context: nil, hints: nil).map {
            Thumbnail(image: $0, isFileIcon: true)
        }
    }
}
