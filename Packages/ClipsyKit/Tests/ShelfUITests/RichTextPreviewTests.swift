import AppKit
import Store
import SwiftUI
import Testing
@testable import ShelfUI

struct RichTextPreviewTests {
    private static func rtf(_ text: String, color: NSColor, size: CGFloat = 24) throws -> [Representation] {
        let string = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size),
            .foregroundColor: color
        ])
        let data = try string.data(
            from: NSRange(location: 0, length: string.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        return [Representation(itemIndex: 0, uti: NSPasteboard.PasteboardType.rtf.rawValue, data: data)]
    }

    private static func luminance(_ white: CGFloat) throws -> RichTextPreview.Luminance {
        try #require(RichTextPreview.Luminance(NSColor(white: white, alpha: 1)))
    }

    @Test func `black text keeps its color on a light card`() throws {
        let preview = try #require(RichTextPreview.attributedString(
            from: Self.rtf("Hello", color: .black),
            bodySize: 13,
            background: Self.luminance(1)
        ))
        #expect(String(preview.characters) == "Hello")
        #expect(preview.runs.allSatisfy { $0.foregroundColor != nil })
    }

    @Test func `black text falls back to the label color on a dark card`() throws {
        let preview = try #require(RichTextPreview.attributedString(
            from: Self.rtf("Hello", color: .black),
            bodySize: 13,
            background: Self.luminance(0.12)
        ))
        #expect(preview.runs.allSatisfy { $0.foregroundColor == nil })
    }

    @Test func `plain text without RTF has no rich preview`() throws {
        let plain = Representation(
            itemIndex: 0,
            uti: NSPasteboard.PasteboardType.string.rawValue,
            data: Data("Hello".utf8)
        )
        let background = try Self.luminance(1)
        #expect(RichTextPreview.attributedString(from: [plain], bodySize: 13, background: background) == nil)
    }

    @Test func `preview is cut to the maximum length`() throws {
        let long = String(repeating: "a", count: RichTextPreview.maximumLength * 2)
        let preview = try #require(RichTextPreview.attributedString(
            from: Self.rtf(long, color: .black),
            bodySize: 13,
            background: Self.luminance(1)
        ))
        #expect(preview.characters.count == RichTextPreview.maximumLength)
    }

    @Test func `black on white has the maximum contrast`() throws {
        let ratio = try Self.luminance(0).contrastRatio(to: Self.luminance(1))
        #expect(abs(ratio - 21) < 0.01)
    }
}
