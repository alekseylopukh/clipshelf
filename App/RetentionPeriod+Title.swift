import Foundation
import Store

extension RetentionPeriod {
    var title: LocalizedStringResource {
        switch self {
        case .day: "1 Day"
        case .week: "1 Week"
        case .month: "1 Month"
        case .year: "1 Year"
        case .forever: "Forever"
        }
    }
}
