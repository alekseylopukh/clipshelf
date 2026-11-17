import Foundation
import Observation
import os

@MainActor
@Observable
public final class RetentionSettings {
    public static let periodKey = "RetentionPeriod"
    public static let purgeInterval = Duration.seconds(60 * 60)

    public private(set) var period: RetentionPeriod
    /// a lower limit that waits for the user to confirm, because it would remove older cards
    public private(set) var pendingPeriod: RetentionPeriod?

    @ObservationIgnored private let repository: CardRepository
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private let logger = Logger(subsystem: "app.gonar.clipsy", category: "Retention")

    public init(
        repository: CardRepository,
        defaults: UserDefaults = .standard,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.repository = repository
        self.defaults = defaults
        self.clock = clock
        period = defaults.string(forKey: Self.periodKey).flatMap(RetentionPeriod.init(rawValue:)) ?? .default
    }

    public func select(_ newPeriod: RetentionPeriod) async throws {
        pendingPeriod = nil
        guard newPeriod != period else { return }
        if newPeriod < period, let cutoff = newPeriod.cutoff(before: .now),
           try await repository.hasHistory(olderThan: cutoff)
        {
            pendingPeriod = newPeriod
        } else {
            try await apply(newPeriod)
        }
    }

    public func confirmPendingChange() async throws {
        guard let pendingPeriod else { return }
        self.pendingPeriod = nil
        try await apply(pendingPeriod)
    }

    public func cancelPendingChange() {
        pendingPeriod = nil
    }

    public func eraseHistory() async throws {
        try await repository.eraseHistory()
    }

    /// purges now and then every hour until the calling task is cancelled
    public func runPurgeSchedule() async throws {
        while true {
            do {
                try await purgeExpiredCards()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logger.error("purge failed: \(String(describing: type(of: error)), privacy: .public)")
            }
            try await clock.sleep(for: Self.purgeInterval)
        }
    }

    private func apply(_ newPeriod: RetentionPeriod) async throws {
        let isLower = newPeriod < period
        period = newPeriod
        defaults.set(newPeriod.rawValue, forKey: Self.periodKey)
        if isLower {
            try await purgeExpiredCards()
        }
    }

    private func purgeExpiredCards() async throws {
        guard let cutoff = period.cutoff(before: .now) else { return }
        try await repository.purge(olderThan: cutoff)
    }
}
