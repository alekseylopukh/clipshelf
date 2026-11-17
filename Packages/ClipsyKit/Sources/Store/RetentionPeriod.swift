import Foundation

public enum RetentionPeriod: String, CaseIterable, Comparable, Sendable {
    case day
    case week
    case month
    case year
    case forever

    public static let `default` = RetentionPeriod.month

    public static func < (lhs: RetentionPeriod, rhs: RetentionPeriod) -> Bool {
        allCases.firstIndex(of: lhs) ?? 0 < allCases.firstIndex(of: rhs) ?? 0
    }

    /// nil for `forever`
    public func cutoff(before date: Date, calendar: Calendar = .current) -> Date? {
        let component: Calendar.Component? = switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        case .forever: nil
        }
        guard let component else { return nil }
        return calendar.date(byAdding: component, value: -1, to: date)
    }
}
