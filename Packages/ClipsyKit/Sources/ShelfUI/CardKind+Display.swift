import Store

extension CardKind {
    var name: String {
        switch self {
        case .text: String(localized: "Text", comment: "Card type name")
        case .link: String(localized: "Link", comment: "Card type name")
        case .image: String(localized: "Image", comment: "Card type name")
        case .file: String(localized: "File", comment: "Card type name")
        case .color: String(localized: "Color", comment: "Card type name")
        case .unknown: String(localized: "Other", comment: "Card type name")
        }
    }

    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .file: "doc"
        case .color: "paintpalette"
        case .unknown: "questionmark.square.dashed"
        }
    }
}
