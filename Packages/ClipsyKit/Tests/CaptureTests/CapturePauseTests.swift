import Foundation
import Synchronization
import Testing
@testable import Capture

private final class FakeWallClock: WallClock {
    private let current: Mutex<Date>

    init(now: Date) {
        current = Mutex(now)
    }

    var now: Date {
        get { current.withLock { $0 } }
        set { current.withLock { $0 = newValue } }
    }

    func sleep(until date: Date) async throws {
        while now < date {
            try await Task.sleep(for: .milliseconds(1))
        }
    }
}

struct TomorrowCase: Sendable {
    let now: String
    let timeZone: String
    let expected: String
}

@MainActor
final class CapturePauseTests {
    private let suiteName = "CapturePauseTests-\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let clock: FakeWallClock

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        clock = FakeWallClock(now: start)
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makePause(calendar: Calendar = Calendar(identifier: .gregorian)) -> CapturePause {
        CapturePause(defaults: defaults, clock: clock, calendar: calendar)
    }

    private func waitUntilResumed(_ pause: CapturePause) async {
        for await isPaused in Observations({ pause.isPaused }) where isPaused == false {
            return
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func `pause resumes at deadline`() async throws {
        let pause = makePause()

        pause.pause(.fifteenMinutes)
        #expect(pause.isPaused)
        #expect(pause.resumeDate == start.addingTimeInterval(15 * 60))

        clock.now = start.addingTimeInterval(14 * 60)
        try await Task.sleep(for: .milliseconds(20))
        #expect(pause.isPaused)

        clock.now = start.addingTimeInterval(15 * 60)
        await waitUntilResumed(pause)
        #expect(pause.resumeDate == nil)
        #expect(defaults.object(forKey: CapturePause.pausedUntilKey) == nil)
    }

    private nonisolated static let fixedDurations: [(PauseDuration, TimeInterval)] = [
        (.fifteenMinutes, 15 * 60),
        (.oneHour, 60 * 60),
        (.eightHours, 8 * 60 * 60)
    ]

    private nonisolated static let tomorrowCases: [TomorrowCase] = [
        TomorrowCase(now: "2026-11-17T15:30:00", timeZone: "Europe/Berlin", expected: "2026-11-18T00:00:00"),
        TomorrowCase(now: "2026-11-17T00:00:00", timeZone: "Europe/Berlin", expected: "2026-11-18T00:00:00"),
        TomorrowCase(now: "2026-03-28T23:30:00", timeZone: "Europe/Berlin", expected: "2026-03-29T00:00:00"),
        TomorrowCase(now: "2026-03-29T12:00:00", timeZone: "Europe/Berlin", expected: "2026-03-30T00:00:00"),
        TomorrowCase(now: "2026-11-17T23:59:00", timeZone: "America/Los_Angeles", expected: "2026-11-18T00:00:00")
    ]

    @Test(arguments: fixedDurations)
    func `fixed durations add elapsed time`(duration: PauseDuration, seconds: TimeInterval) {
        #expect(duration.resumeDate(after: start, calendar: .current) == start.addingTimeInterval(seconds))
    }

    @Test(arguments: tomorrowCases)
    func `until tomorrow uses calendar`(case tomorrow: TomorrowCase) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: tomorrow.timeZone))
        let style = Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()
            .time(includingFractionalSeconds: false)
        let resumeDate = try #require(PauseDuration.untilTomorrow.resumeDate(
            after: style.parse(tomorrow.now),
            calendar: calendar
        ))

        #expect(try resumeDate == (style.parse(tomorrow.expected)))
    }

    @Test func `until resumed has no resume date and survives relaunch`() {
        makePause().pause(.untilResumed)

        let relaunched = makePause()
        #expect(relaunched.isPaused)
        #expect(relaunched.resumeDate == nil)
    }

    @Test func `timed pause survives relaunch`() {
        makePause().pause(.oneHour)

        let relaunched = makePause()
        #expect(relaunched.resumeDate == start.addingTimeInterval(60 * 60))
    }

    @Test func `pause that ended while quit is cleared at launch`() {
        makePause().pause(.fifteenMinutes)
        clock.now = start.addingTimeInterval(16 * 60)

        let relaunched = makePause()
        #expect(relaunched.isPaused == false)
        #expect(defaults.object(forKey: CapturePause.pausedUntilKey) == nil)
    }

    @Test func `toggle pauses until resumed and resumes`() {
        let pause = makePause()

        pause.toggle()
        #expect(pause.isPaused)
        #expect(pause.resumeDate == nil)

        pause.toggle()
        #expect(pause.isPaused == false)
    }

    @Test func `resume cancels the deadline`() async throws {
        let pause = makePause()
        pause.pause(.fifteenMinutes)
        pause.resume()
        pause.pause(.untilResumed)

        clock.now = start.addingTimeInterval(15 * 60)
        try await Task.sleep(for: .milliseconds(20))
        #expect(pause.isPaused)
    }
}
