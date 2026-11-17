import Foundation

public enum PauseDuration: CaseIterable, Sendable {
    case fifteenMinutes
    case oneHour
    case eightHours
    case untilTomorrow
    case untilResumed

    /// nil when the pause lasts until resumed; tomorrow starts at midnight in `calendar`
    public func resumeDate(after now: Date, calendar: Calendar) -> Date? {
        switch self {
        case .fifteenMinutes:
            now.addingTimeInterval(15 * 60)
        case .oneHour:
            now.addingTimeInterval(60 * 60)
        case .eightHours:
            now.addingTimeInterval(8 * 60 * 60)
        case .untilTomorrow:
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        case .untilResumed:
            nil
        }
    }
}
