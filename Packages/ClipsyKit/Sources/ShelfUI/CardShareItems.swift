import AppKit
import Store
import UniformTypeIdentifiers

@MainActor
enum CardShareItems {
    static func items(for cards: [(card: CardSummary, representations: [Representation])]) -> [Any] {
        cards.flatMap { card, representations -> [Any] in
            switch card.kind {
            case .text, .color:
                let text = representations.first { $0.uti == UTType.utf8PlainText.identifier }
                    .flatMap { String(bytes: $0.data, encoding: .utf8) }
                return text.map { [$0] } ?? []
            case .link, .file:
                return card.openableURLs(in: representations)
            case .image:
                let image = representations.first { UTType($0.uti)?.conforms(to: .image) ?? false }
                    .flatMap { NSImage(data: $0.data) }
                return image.map { [$0] } ?? []
            case .unknown:
                return []
            }
        }
    }
}
