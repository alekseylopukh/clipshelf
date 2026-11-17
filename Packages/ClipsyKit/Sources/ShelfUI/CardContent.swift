import Foundation
import Store
import SwiftUI

struct CardContent {
    let metadata: CardMetadata
    let isCodeLike: Bool

    init(_ card: CardSummary) {
        metadata = card.decodedMetadata
        isCodeLike = card.kind == .text && CodeLikeText.isCodeLike(card.preview ?? "")
    }

    var host: String? {
        metadata.url.flatMap { URL(string: $0)?.host() }
    }

    var swatch: Color? {
        guard let color = metadata.color.flatMap(CardColor.init(copiedText:)) else { return nil }
        return Color(
            .sRGB,
            red: Double(color.red) / 255,
            green: Double(color.green) / 255,
            blue: Double(color.blue) / 255
        )
    }

    func accessibilityValue(of card: CardSummary) -> String? {
        switch card.kind {
        case .text:
            card.preview?.split(whereSeparator: \.isNewline).first.map(String.init)
        case .link:
            metadata.pageTitle ?? metadata.url
        case .file:
            metadata.fileNames?.formatted(.list(type: .and))
        case .color:
            metadata.color
        case .image, .unknown:
            nil
        }
    }
}

extension CardSummary {
    var decodedMetadata: CardMetadata {
        guard let json = metadata?.data(using: .utf8) else { return CardMetadata() }
        return (try? JSONDecoder().decode(CardMetadata.self, from: json)) ?? CardMetadata()
    }

    var displayDate: Date {
        lastCopiedAt ?? createdAt
    }
}
