import Foundation
import Testing
@testable import Store

struct StorageSummaryTests {
    let repository: CardRepository

    init() throws {
        repository = try CardRepository(database: AppDatabase.temporary())
    }

    @Test func `summary counts payload bytes`() async throws {
        let payloadSize = 256 * 1024
        let before = try await repository.storageSummary()

        try await record(byte: 1, data: Data(repeating: 1, count: payloadSize))
        try await record(byte: 2, data: Data([2]))
        let after = try await repository.storageSummary()

        #expect(before.cardCount == 0)
        #expect(after.cardCount == 2)
        #expect(after.byteCount - before.byteCount >= Int64(payloadSize))
    }

    @Test func `summary counts thumbnails`() async throws {
        let thumbnailSize = 256 * 1024
        let payloads = PayloadStore(directory: repository.database.directory)
        let before = try await repository.storageSummary()

        try FileManager.default.createDirectory(at: payloads.thumbnailsDirectory, withIntermediateDirectories: true)
        try Data(repeating: 0, count: thumbnailSize).write(to: payloads.thumbnailsDirectory.appending(path: "a.png"))
        let after = try await repository.storageSummary()

        #expect(after.byteCount - before.byteCount >= Int64(thumbnailSize))
    }

    private func record(byte: UInt8, data: Data) async throws {
        try await repository.record(
            NewCard(
                kind: .text,
                representations: [Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: data)],
                contentHash: Data([byte]),
                previewText: "Card \(byte)",
                metadata: nil,
                sourceApp: SourceApp(bundleID: "com.example.notes", name: "Notes")
            )
        )
    }
}
