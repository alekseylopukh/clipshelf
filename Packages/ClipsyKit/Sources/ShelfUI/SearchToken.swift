import Foundation
import Store

enum SearchToken: Hashable, Identifiable {
    case kind(CardKind)
    case app(SourceApp)
    case date(DateRangeFilter)
    case board(id: Int64)

    enum Category: CaseIterable {
        case kind
        case app
        case date
        case board
    }

    static let kinds: [CardKind] = [.text, .link, .image, .file, .color, .unknown]
    static let dateRanges: [DateRangeFilter] = [.today, .yesterday, .last7Days, .last30Days]

    var category: Category {
        switch self {
        case .kind: .kind
        case .app: .app
        case .date: .date
        case .board: .board
        }
    }

    var id: Self {
        self
    }

    static func filter(of tokens: [Self]) -> CardFilter {
        var filter = CardFilter()
        for token in tokens {
            switch token {
            case let .kind(kind): filter.kind = kind
            case let .app(app): filter.sourceAppBundleID = app.bundleID
            case let .date(range): filter.dateRange = range
            case let .board(id): filter.boardID = id
            }
        }
        return filter
    }
}

extension SearchToken.Category {
    var name: String {
        switch self {
        case .kind: String(localized: "Type", comment: "Search filter category: card type")
        case .app: String(localized: "App", comment: "Search filter category: the app a card was copied from")
        case .date: String(localized: "Date", comment: "Search filter category: when a card was copied")
        case .board: String(localized: "Board", comment: "VoiceOver name of the board a search result is on")
        }
    }

    var symbolName: String {
        switch self {
        case .kind: "square.grid.2x2"
        case .app: "app"
        case .date: "calendar"
        case .board: "square.stack"
        }
    }
}

extension DateRangeFilter {
    var name: String {
        switch self {
        case .today: String(localized: "Today", comment: "Search date filter")
        case .yesterday: String(localized: "Yesterday", comment: "Search date filter")
        case .last7Days: String(localized: "Last 7 Days", comment: "Search date filter")
        case .last30Days: String(localized: "Last 30 Days", comment: "Search date filter")
        case let .custom(from, through):
            (min(from, through) ..< max(from, through)).formatted(.interval.day().month(.abbreviated))
        }
    }
}
