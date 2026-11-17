import AppKit
import Store
import Testing
import UniformTypeIdentifiers
@testable import ShelfUI

@MainActor
struct CardShareItemsTests {
    private static func card(_ id: Int64, _ kind: CardKind, metadata: String? = nil) -> CardSummary {
        CardSummary(id: id, kind: kind, metadata: metadata, createdAt: Date(timeIntervalSince1970: 0))
    }

    @Test func `text link and files share their content`() {
        let file = URL(filePath: "/tmp/a.txt")
        let items = CardShareItems.items(for: [
            (
                Self.card(1, .text),
                [Representation(itemIndex: 0, uti: UTType.utf8PlainText.identifier, data: Data("plan".utf8))]
            ),
            (Self.card(2, .link, metadata: #"{"url":"https:\/\/example.com"}"#), []),
            (
                Self.card(3, .file),
                [Representation(itemIndex: 0, uti: UTType.fileURL.identifier, data: file.dataRepresentation)]
            ),
            (Self.card(4, .unknown), [Representation(itemIndex: 0, uti: "com.example.private", data: Data([1]))])
        ])

        #expect(items.count == 3)
        #expect(items.first as? String == "plan")
        #expect(items.dropFirst().first as? URL == URL(string: "https://example.com"))
        #expect(items.last as? URL == file)
    }
}
