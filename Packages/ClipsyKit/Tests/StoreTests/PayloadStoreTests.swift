import CryptoKit
import Foundation
import GRDB
import Testing
@testable import Store

struct PayloadStoreTests {
    let database: AppDatabase
    let store: PayloadStore

    init() throws {
        database = try AppDatabase.temporary()
        store = PayloadStore(directory: database.directory)
    }

    private func fileExists(_ hash: String) -> Bool {
        FileManager.default.fileExists(atPath: store.fileURL(for: hash).path(percentEncoded: false))
    }

    private func fileHash(of payload: Payload) throws -> String {
        guard case let .file(hash) = payload else { return try #require(nil as String?) }
        return hash
    }

    @Test func `small payload stays inline`() throws {
        let data = Data(repeating: 1, count: PayloadStore.inlineLimit - 1)
        let payload = try store.store(data)
        #expect(payload == .inline(data))
        #expect(try store.data(for: payload) == data)
        #expect(FileManager.default.fileExists(atPath: store.payloadsDirectory.path(percentEncoded: false)) == false)
    }

    @Test func `large payload is content addressed`() throws {
        let data = Data(repeating: 2, count: PayloadStore.inlineLimit)
        let hash = try fileHash(of: store.store(data))
        #expect(hash == SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
        #expect(store.fileURL(for: hash).deletingLastPathComponent().lastPathComponent == String(hash.prefix(2)))
        #expect(try Data(contentsOf: store.fileURL(for: hash)) == data)
        #expect(try store.data(for: .file(hash: hash)) == data)
    }

    @Test func `identical payloads share one file`() throws {
        let data = Data(repeating: 3, count: 10000)
        let first = try store.store(data)
        let second = try store.store(data)
        #expect(first == second)
        let hash = try fileHash(of: first)
        let siblings = try FileManager.default.contentsOfDirectory(
            at: store.fileURL(for: hash).deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        )
        #expect(siblings.map(\.lastPathComponent) == [hash])
    }

    @Test func `garbage collection keeps referenced files`() throws {
        let kept = try fileHash(of: store.store(Data(repeating: 4, count: 5000)))
        let dropped = try fileHash(of: store.store(Data(repeating: 5, count: 5000)))
        let thumbnailKept = String(repeating: "a", count: 64)
        let thumbnailDropped = String(repeating: "b", count: 64)
        try FileManager.default.createDirectory(at: store.thumbnailsDirectory, withIntermediateDirectories: true)
        for name in [thumbnailKept, thumbnailDropped] {
            try Data([0]).write(to: store.thumbnailsDirectory.appending(path: "\(name).png"))
        }

        try store.collectGarbage(referenced: [kept, thumbnailKept])

        #expect(fileExists(kept))
        #expect(fileExists(dropped) == false)
        let thumbnails = try FileManager.default
            .contentsOfDirectory(atPath: store.thumbnailsDirectory.path(percentEncoded: false))
        #expect(thumbnails == ["\(thumbnailKept).png"])
    }

    @Test func `crash before insert leaves only orphan`() throws {
        let hash = try fileHash(of: store.store(Data(repeating: 6, count: 5000)))

        let referenced = try database.pool.read { connection in
            try String.fetchSet(
                connection,
                sql: "SELECT payload_hash FROM representation WHERE payload_hash IS NOT NULL"
            )
        }
        #expect(referenced.isEmpty)
        #expect(fileExists(hash))

        try store.collectGarbage(referenced: referenced)
        #expect(fileExists(hash) == false)
    }
}
