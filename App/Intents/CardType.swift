import AppIntents
import Store

enum CardType: String, AppEnum {
    case text
    case link
    case image
    case file
    case color
    case other

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Card Type"
    static let caseDisplayRepresentations: [CardType: DisplayRepresentation] = [
        .text: DisplayRepresentation(title: "Text", image: .init(systemName: "text.alignleft")),
        .link: DisplayRepresentation(title: "Link", image: .init(systemName: "link")),
        .image: DisplayRepresentation(title: "Image", image: .init(systemName: "photo")),
        .file: DisplayRepresentation(title: "File", image: .init(systemName: "doc")),
        .color: DisplayRepresentation(title: "Color", image: .init(systemName: "paintpalette")),
        .other: DisplayRepresentation(title: "Other", image: .init(systemName: "questionmark.square.dashed"))
    ]

    init(_ kind: CardKind) {
        self = switch kind {
        case .text: .text
        case .link: .link
        case .image: .image
        case .file: .file
        case .color: .color
        case .unknown: .other
        }
    }

    var kind: CardKind {
        switch self {
        case .text: .text
        case .link: .link
        case .image: .image
        case .file: .file
        case .color: .color
        case .other: .unknown
        }
    }
}
