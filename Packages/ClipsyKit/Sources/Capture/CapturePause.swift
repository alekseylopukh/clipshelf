import Foundation
import Observation

@MainActor
@Observable
public final class CapturePause {
    public static let pausedUntilKey = "CapturePausedUntil"

    /// nil while capturing; `Date.distantFuture` while paused until resumed
    private var pausedUntil: Date? {
        didSet {
            defaults.set(pausedUntil, forKey: Self.pausedUntilKey)
            scheduleResume()
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let clock: any WallClock
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var resumeTask: Task<Void, Never>?

    public init(
        defaults: UserDefaults = .standard,
        clock: any WallClock = SystemWallClock(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.defaults = defaults
        self.clock = clock
        self.calendar = calendar
        let stored = defaults.object(forKey: Self.pausedUntilKey) as? Date
        pausedUntil = stored.flatMap { $0 > clock.now ? $0 : nil }
        if pausedUntil != stored {
            defaults.set(pausedUntil, forKey: Self.pausedUntilKey)
        }
        scheduleResume()
    }

    public var isPaused: Bool {
        pausedUntil != nil
    }

    /// nil while capturing or while paused until resumed
    public var resumeDate: Date? {
        pausedUntil == .distantFuture ? nil : pausedUntil
    }

    public func pause(_ duration: PauseDuration) {
        pausedUntil = duration.resumeDate(after: clock.now, calendar: calendar) ?? .distantFuture
    }

    public func resume() {
        pausedUntil = nil
    }

    public func toggle() {
        if isPaused {
            resume()
        } else {
            pause(.untilResumed)
        }
    }

    private func scheduleResume() {
        resumeTask?.cancel()
        resumeTask = nil
        guard let date = resumeDate else { return }
        resumeTask = Task { [weak self, clock] in
            do {
                try await clock.sleep(until: date)
            } catch {
                return
            }
            self?.resumeIfDue(date)
        }
    }

    private func resumeIfDue(_ date: Date) {
        guard pausedUntil == date else { return }
        if clock.now >= date {
            resume()
        } else {
            scheduleResume()
        }
    }
}
