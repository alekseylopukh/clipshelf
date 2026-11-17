import Foundation

public enum DateRangeFilter: Sendable, Hashable {
    case today
    case yesterday
    case last7Days
    case last30Days
    /// whole calendar days, both ends included
    case custom(from: Date, through: Date)

    public func interval(now: Date, calendar: Calendar) -> Range<Date> {
        func day(_ offset: Int, from date: Date = now) -> Date {
            let start = calendar.startOfDay(for: date)
            guard let shifted = calendar.date(byAdding: .day, value: offset, to: start) else {
                fatalError("adding whole days to a start of day always yields a date")
            }
            return calendar.startOfDay(for: shifted)
        }
        return switch self {
        case .today: day(0) ..< day(1)
        case .yesterday: day(-1) ..< day(0)
        case .last7Days: day(-6) ..< day(1)
        case .last30Days: day(-29) ..< day(1)
        case let .custom(from, through): day(0, from: min(from, through)) ..< day(1, from: max(from, through))
        }
    }
}
