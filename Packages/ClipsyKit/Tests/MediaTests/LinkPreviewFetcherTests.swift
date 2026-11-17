import Foundation
import Testing
@testable import Media
@testable import Store

@MainActor
struct LinkPreviewFetcherTests {
    private final class FakeProvider: LinkMetadataProviding {
        var preview = LinkPreview(title: nil, imageData: nil)
        private(set) var requestedURLs: [URL] = []

        func preview(for url: URL) async throws -> LinkPreview {
            requestedURLs.append(url)
            return preview
        }
    }

    private let repository: CardRepository
    private let thumbnails: ThumbnailCache
    private let provider = FakeProvider()

    init() throws {
        let database = try AppDatabase.temporary()
        repository = CardRepository(database: database)
        thumbnails = ThumbnailCache(directory: repository.thumbnailsDirectory)
    }

    @Test func `no fetch when off`() async throws {
        let id = try await recordLink("https://example.com/garden")
        provider.preview = LinkPreview(title: "Garden Almanac", imageData: nil)

        try await fetcher(isEnabled: false).fetchPreview(for: id)

        #expect(provider.requestedURLs.isEmpty)
        #expect(try await repository.search("almanac").isEmpty)
    }

    @Test func `title is indexed`() async throws {
        let id = try await recordLink("https://example.com/garden")
        provider.preview = LinkPreview(title: "  Garden Almanac\n", imageData: nil)
        let fetcher = fetcher(isEnabled: true)

        try await fetcher.fetchPreview(for: id)
        try await fetcher.fetchPreview(for: id)

        #expect(provider.requestedURLs == [URL(string: "https://example.com/garden")])
        let result = try #require(try await repository.search("almanac").first)
        #expect(result.id == id)
        #expect(try metadata(of: result.card).pageTitle == "Garden Almanac")
        #expect(try await repository.search("example").map(\.id) == [id])
    }

    @Test func `image is cached in thumbnails`() async throws {
        let id = try await recordLink("https://example.com/photo")
        provider.preview = try LinkPreview(title: nil, imageData: ThumbnailCacheTests.pngData(width: 1600, height: 900))

        try await fetcher(isEnabled: true).fetchPreview(for: id)

        let card = try #require(try await repository.search("example").first?.card)
        let hash = try #require(card.contentHash)
        let metadata = try metadata(of: card)
        #expect(metadata.pixelWidth == 800)
        #expect(metadata.pixelHeight == 450)
        let image = try #require(await thumbnails.thumbnail(forHash: hash, maxPixelSize: 800) { [] })
        #expect(image.width == 800)
    }

    @Test func `undecodable image and blank title store nothing`() async throws {
        let id = try await recordLink("https://example.com/empty")
        provider.preview = LinkPreview(title: " ", imageData: Data("not an image".utf8))

        try await fetcher(isEnabled: true).fetchPreview(for: id)

        let card = try #require(try await repository.search("example").first?.card)
        #expect(try metadata(of: card) == CardMetadata(url: "https://example.com/empty"))
    }

    @Test(arguments: ["mailto:someone@example.com", "ftp://example.com/file", "custom://example"])
    func `non-web links are not fetched`(_ url: String) async throws {
        let id = try await recordLink(url)

        try await fetcher(isEnabled: true).fetchPreview(for: id)

        #expect(provider.requestedURLs.isEmpty)
    }

    private func metadata(of card: CardSummary) throws -> CardMetadata {
        try JSONDecoder().decode(CardMetadata.self, from: Data(#require(card.metadata).utf8))
    }

    private func fetcher(isEnabled: Bool) -> LinkPreviewFetcher {
        LinkPreviewFetcher(
            provider: provider,
            repository: repository,
            thumbnails: thumbnails,
            maxPixelSize: 800
        ) { isEnabled }
    }

    private func recordLink(_ url: String) async throws -> Int64 {
        try await repository.record(NewCard(
            kind: .link,
            representations: [Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data(url.utf8))],
            contentHash: Data(url.utf8),
            previewText: url,
            metadata: #"{"url":"\#(url)"}"#,
            sourceApp: SourceApp(bundleID: "com.example.browser", name: "Browser"),
            url: url
        ))
    }
}
