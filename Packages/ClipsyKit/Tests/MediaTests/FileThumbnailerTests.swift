import CoreGraphics
import Foundation
import Synchronization
import Testing
@testable import Media

struct FileThumbnailerTests {
    final class FakeGenerator: FileThumbnailGenerating {
        let calls = Mutex(0)
        let fails: Bool

        init(fails: Bool = false) {
            self.fails = fails
        }

        func thumbnail(of _: URL, pixelSize: CGFloat) async throws -> CGImage {
            calls.withLock { $0 += 1 }
            if fails {
                throw CocoaError(.fileReadUnknown)
            }
            let side = Int(pixelSize)
            let context = try #require(CGContext(
                data: nil,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            return try #require(context.makeImage())
        }
    }

    private static func temporaryFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "FileThumbnailerTests-\(UUID().uuidString).txt")
        try Data("fixture".utf8).write(to: url)
        return url
    }

    @Test
    func `missing file falls back to icon`() async throws {
        let generator = FakeGenerator()
        let thumbnailer = FileThumbnailer(generator: generator)
        let missing = FileManager.default.temporaryDirectory.appending(path: "missing-\(UUID().uuidString).pdf")

        let thumbnail = try #require(try await thumbnailer.thumbnail(of: missing, pixelSize: 64))

        #expect(thumbnail.isFileIcon)
        #expect(generator.calls.withLock { $0 } == 0)
    }

    @Test
    func `failed generation falls back to icon`() async throws {
        let url = try Self.temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let thumbnailer = FileThumbnailer(generator: FakeGenerator(fails: true))

        let thumbnail = try #require(try await thumbnailer.thumbnail(of: url, pixelSize: 64))

        #expect(thumbnail.isFileIcon)
    }

    @Test
    func `thumbnail is cached per file and size`() async throws {
        let url = try Self.temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let generator = FakeGenerator()
        let thumbnailer = FileThumbnailer(generator: generator)

        let first = try #require(try await thumbnailer.thumbnail(of: url, pixelSize: 64))
        _ = try await thumbnailer.thumbnail(of: url, pixelSize: 64)
        _ = try await thumbnailer.thumbnail(of: url, pixelSize: 128)

        #expect(first.isFileIcon == false)
        #expect(first.image.width == 64)
        #expect(generator.calls.withLock { $0 } == 2)
    }
}
