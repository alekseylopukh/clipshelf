import CoreGraphics
import Foundation
import ImageIO
import Synchronization
import Testing
import UniformTypeIdentifiers
@testable import Media

struct ThumbnailCacheTests {
    struct Fit: Sendable, CustomTestStringConvertible {
        let width: Int
        let height: Int
        let expectedWidth: Int
        let expectedHeight: Int

        var testDescription: String {
            "\(width)×\(height)"
        }
    }

    static func pngData(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "ThumbnailCacheTests-\(UUID().uuidString)")
    }

    @Test(arguments: [
        Fit(width: 1600, height: 800, expectedWidth: 200, expectedHeight: 100),
        Fit(width: 300, height: 1200, expectedWidth: 50, expectedHeight: 200)
    ])
    func `thumbnail fits requested size`(_ fit: Fit) async throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = try Self.pngData(width: fit.width, height: fit.height)
        let cache = ThumbnailCache(directory: directory)

        let image = try #require(await cache.thumbnail(forHash: "0a1b", maxPixelSize: 200) {
            [Data("not an image".utf8), data]
        })

        #expect(image.width == fit.expectedWidth)
        #expect(image.height == fit.expectedHeight)
    }

    @Test
    func `thumbnail is cached by hash`() async throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = try Self.pngData(width: 400, height: 400)
        let cache = ThumbnailCache(directory: directory)
        let loads = Mutex(0)
        let candidates: @Sendable () async throws -> [Data] = {
            loads.withLock { $0 += 1 }
            return [data]
        }

        let first = try #require(await cache.thumbnail(forHash: "0a1b", maxPixelSize: 100, candidates: candidates))
        let second = try #require(await cache.thumbnail(forHash: "0a1b", maxPixelSize: 100, candidates: candidates))
        _ = try await cache.thumbnail(forHash: "2c3d", maxPixelSize: 100, candidates: candidates)

        #expect(loads.withLock { $0 } == 2)
        #expect(FileManager.default.fileExists(atPath: cache.fileURL(for: "0a1b").path(percentEncoded: false)))
        #expect(second.width == first.width)
        #expect(second.height == first.height)
    }
}
