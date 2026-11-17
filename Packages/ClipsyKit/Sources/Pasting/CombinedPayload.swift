import AppKit
import Store

public enum CombinedPayload {
    /// cards in paste order; text cards become one string joined with a newline, anything else one item per card
    public static func representations(of cards: [(kind: CardKind, representations: [Representation])])
        -> [Representation]
    {
        guard cards.isEmpty == false else { return [] }
        let plainType = NSPasteboard.PasteboardType.string.rawValue
        let texts = cards.compactMap { card -> String? in
            guard [.text, .link, .color].contains(card.kind),
                  let plain = card.representations.first(where: { $0.uti == plainType }) else { return nil }
            return String(bytes: plain.data, encoding: .utf8)
        }
        if texts.count == cards.count {
            return [Representation(itemIndex: 0, uti: plainType, data: Data(texts.joined(separator: "\n").utf8))]
        }

        var items: [Representation] = []
        for card in cards {
            let base = (items.last?.itemIndex ?? -1) + 1
            let first = card.representations.first?.itemIndex ?? 0
            items += card.representations.map {
                Representation(itemIndex: base + $0.itemIndex - first, uti: $0.uti, data: $0.data)
            }
        }
        return items
    }
}
