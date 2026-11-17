import CryptoKit
import Foundation
import GRDB
import Testing
@testable import Store

struct RetentionTests {
    let database: AppDatabase
    let repository: CardRepository

    init() throws {
        database = try AppDatabase.temporary()
        repository = CardRepository(database: database)
    }

    @Test func `purge keeps board cards and clears their history`() async throws {
        let board = try await repository.createBoard(named: "B", color: "blue")
        let old = try await record(byte: 1, at: 10)
        try await repository.addCards([old], toBoard: board)

        try await repository.purge(olderThan: Date(timeIntervalSince1970: 100))

        #expect(try await repository.cards(in: .history).isEmpty)
        let onBoard = try await repository.cards(in: .board(id: board))
        #expect(onBoard.map(\.id) == [old])
        #expect(onBoard.first?.lastCopiedAt == nil)
        #expect(try await searchRowIDs() == [old])
    }

    @Test func `purge deletes expired history cards`() async throws {
        let expired = try await record(byte: 1, at: 10)
        let atCutoff = try await record(byte: 2, at: 100)
        let recent = try await record(byte: 3, at: 200)

        try await repository.purge(olderThan: Date(timeIntervalSince1970: 100))

        #expect(try await repository.cards(in: .history).map(\.id) == [recent, atCutoff])
        #expect(try await searchRowIDs().contains(expired) == false)
        #expect(try await repository.representations(of: expired).isEmpty)
    }

    @Test func `erase history keeps boards`() async throws {
        let board = try await repository.createBoard(named: "B", color: "blue")
        let onBoard = try await record(byte: 1, at: 10)
        try await record(byte: 2, at: 20)
        try await repository.addCards([onBoard], toBoard: board)

        try await repository.eraseHistory()

        #expect(try await repository.cards(in: .history).isEmpty)
        #expect(try await repository.cards(in: .board(id: board)).map(\.id) == [onBoard])
        #expect(try await repository.boards().map(\.id) == [board])
        #expect(try await searchRowIDs() == [onBoard])
    }

    @Test func `purge collects orphan payloads`() async throws {
        let payloads = PayloadStore(directory: database.directory)
        let expiredData = Data(repeating: 1, count: PayloadStore.inlineLimit)
        let keptData = Data(repeating: 2, count: PayloadStore.inlineLimit)
        try await record(byte: 1, at: 10, data: expiredData)
        try await record(byte: 2, at: 200, data: keptData)
        try FileManager.default.createDirectory(at: payloads.thumbnailsDirectory, withIntermediateDirectories: true)
        for byte: UInt8 in [1, 2] {
            try Data([0]).write(to: payloads.thumbnailsDirectory.appending(path: "\(hex(Data([byte]))).png"))
        }

        try await repository.purge(olderThan: Date(timeIntervalSince1970: 100))

        #expect(fileExists(payloads.fileURL(for: sha256(expiredData))) == false)
        #expect(fileExists(payloads.fileURL(for: sha256(keptData))))
        let thumbnails = try FileManager.default
            .contentsOfDirectory(atPath: payloads.thumbnailsDirectory.path(percentEncoded: false))
        #expect(thumbnails == ["\(hex(Data([2]))).png"])
    }

    @Test(arguments: [
        (RetentionPeriod.day, "2026-03-09T12:00:00Z"),
        (.week, "2026-03-03T12:00:00Z"),
        (.month, "2026-02-10T12:00:00Z"),
        (.year, "2025-03-10T12:00:00Z")
    ])
    func `cutoff is one period earlier`(period: RetentionPeriod, expected: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let now = try Date("2026-03-10T12:00:00Z", strategy: .iso8601)

        #expect(try period.cutoff(before: now, calendar: calendar) == Date(expected, strategy: .iso8601))
    }

    @Test func `forever has no cutoff and month is the default`() {
        #expect(RetentionPeriod.forever.cutoff(before: .now) == nil)
        #expect(RetentionPeriod.default == .month)
    }

    @discardableResult
    private func record(byte: UInt8, at time: TimeInterval, data: Data? = nil) async throws -> Int64 {
        try await repository.record(
            NewCard(
                kind: .text,
                representations: [
                    Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: data ?? Data([byte]))
                ],
                contentHash: Data([byte]),
                previewText: "Card \(byte)",
                metadata: nil,
                sourceApp: SourceApp(bundleID: "com.example.notes", name: "Notes")
            ),
            at: Date(timeIntervalSince1970: time)
        )
    }

    private func searchRowIDs() async throws -> [Int64] {
        try await database.pool.read { connection in
            try Int64.fetchAll(connection, sql: "SELECT rowid FROM card_search ORDER BY rowid")
        }
    }

    private func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ data: Data) -> String {
        hex(Data(SHA256.hash(data: data)))
    }
}
