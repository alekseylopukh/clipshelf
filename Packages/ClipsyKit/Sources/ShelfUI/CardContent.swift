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
        guard let value = metadata.color?.trimmingCharacters(in: .whitespacesAndNewlines),
              let rgb = UInt32(value.hasPrefix("#") ? value.dropFirst() : Substring(value), radix: 16)
        else { return nil }
        return Color(
            .sRGB,
            red: Double(rgb >> 16 & 0xFF) / 255,
            green: Double(rgb >> 8 & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
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
