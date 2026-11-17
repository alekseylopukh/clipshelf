import Foundation
import Store

struct CardDragContent: Sendable, Equatable {
    struct ImageFile: Sendable, Equatable {
        let name: String
        let png: Data
    }

    let items: [[Representation]]
    let reference: Data
    let imageFile: ImageFile?

    @concurrent
    static func make(for card: CardSummary, representations: [Representation]) async throws -> Self {
        var items: [[Representation]] = []
        for representation in representations {
            if items.last?.first?.itemIndex == representation.itemIndex {
                items[items.count - 1].append(representation)
            } else {
                items.append([representation])
            }
        }
        let reference = try await CardReference(cardID: card.id).exported(as: .clipsyCardReference)
        let imageFile = card.kind == .image ? PNGConversion.pngData(from: representations).map {
            ImageFile(name: fileName(for: card), png: $0)
        } : nil
        return Self(items: items, reference: reference, imageFile: imageFile)
    }

    private static func fileName(for card: CardSummary) -> String {
        let title = card.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = title.isEmpty ? card.kind.name : title
        return base.replacing("/", with: "-").replacing(":", with: "-") + ".png"
    }
}
