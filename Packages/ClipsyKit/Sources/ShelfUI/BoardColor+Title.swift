import DesignSystem

extension BoardColor {
    var title: String {
        switch self {
        case .red: String(localized: "Red", comment: "Board color name")
        case .orange: String(localized: "Orange", comment: "Board color name")
        case .yellow: String(localized: "Yellow", comment: "Board color name")
        case .green: String(localized: "Green", comment: "Board color name")
        case .blue: String(localized: "Blue", comment: "Board color name")
        case .purple: String(localized: "Purple", comment: "Board color name")
        case .gray: String(localized: "Gray", comment: "Board color name")
        }
    }
}
