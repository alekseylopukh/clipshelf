import Foundation
import Testing
@testable import Store

@MainActor
final class RetentionSettingsTests {
    private let suiteName = "RetentionSettingsTests-\(UUID().uuidString)"
    private let repository: CardRepository
    private let defaults: UserDefaults
    private let clock = TestClock()
    private let settings: RetentionSettings

    init() throws {
        repository = try CardRepository(database: AppDatabase.temporary())
        defaults = try #require(UserDefaults(suiteName: suiteName))
        settings = RetentionSettings(repository: repository, defaults: defaults, clock: clock)
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test func `lowering retention needs confirmation`() async throws {
        let old = try await record(byte: 1, daysAgo: 3)

        try await settings.select(.day)

        #expect(settings.pendingPeriod == .day)
        #expect(settings.period == .month)
        #expect(try await historyIDs() == [old])

        try await settings.confirmPendingChange()

        #expect(settings.pendingPeriod == nil)
        #expect(settings.period == .day)
        #expect(defaults.string(forKey: RetentionSettings.periodKey) == RetentionPeriod.day.rawValue)
        #expect(try await historyIDs().isEmpty)
    }

    @Test func `cancel keeps the old limit and the cards`() async throws {
        let old = try await record(byte: 1, daysAgo: 3)

        try await settings.select(.day)
        settings.cancelPendingChange()

        #expect(settings.pendingPeriod == nil)
        #expect(settings.period == .month)
        #expect(defaults.string(forKey: RetentionSettings.periodKey) == nil)
        #expect(try await historyIDs() == [old])
    }

    @Test(arguments: [RetentionPeriod.year, .forever])
    func `raising the limit applies without confirmation`(period: RetentionPeriod) async throws {
        try await record(byte: 1, daysAgo: 40)

        try await settings.select(period)

        #expect(settings.pendingPeriod == nil)
        #expect(settings.period == period)
        #expect(try await historyIDs().count == 1)
    }

    @Test func `lowering without older cards applies without confirmation`() async throws {
        let recent = try await record(byte: 1, daysAgo: 0)

        try await settings.select(.week)

        #expect(settings.pendingPeriod == nil)
        #expect(settings.period == .week)
        #expect(try await historyIDs() == [recent])
    }

    @Test func `stored limit is read at init`() {
        defaults.set(RetentionPeriod.year.rawValue, forKey: RetentionSettings.periodKey)

        #expect(RetentionSettings(repository: repository, defaults: defaults).period == .year)
    }

    @Test func `purge schedule runs at launch`() async throws {
        let recent = try await record(byte: 1, daysAgo: 0)
        try await record(byte: 2, daysAgo: 40)
        var sleeps = clock.sleeps.makeAsyncIterator()

        let schedule = Task { try await settings.runPurgeSchedule() }
        defer { schedule.cancel() }

        _ = await sleeps.next()
        #expect(try await historyIDs() == [recent])

        try await record(byte: 3, daysAgo: 40)
        clock.advance(by: RetentionSettings.purgeInterval - .seconds(1))
        #expect(try await historyIDs().count == 2)

        clock.advance(by: .seconds(1))
        _ = await sleeps.next()
        #expect(try await historyIDs() == [recent])
    }

    @discardableResult
    private func record(byte: UInt8, daysAgo: Int) async throws -> Int64 {
        try await repository.record(
            NewCard(
                kind: .text,
                representations: [Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data([byte]))],
                contentHash: Data([byte]),
                previewText: "Card \(byte)",
                metadata: nil,
                sourceApp: SourceApp(bundleID: "com.example.notes", name: "Notes")
            ),
            at: Date.now.addingTimeInterval(-Double(daysAgo) * 24 * 60 * 60)
        )
    }

    private func historyIDs() async throws -> [Int64] {
        try await repository.cards(in: .history).map(\.id)
    }
}
