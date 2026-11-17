import AppKit
import Store
import Testing
@testable import Capture

private let fileURL = "public.file-url"
private let plainText = "public.utf8-plain-text"

private func text(_ string: String) -> [[(String, Data)]] {
    [[(plainText, Data(string.utf8))]]
}

private struct Case: Sendable, CustomTestStringConvertible {
    let name: String
    let items: [[(String, Data)]]
    let expected: CardKind

    var testDescription: String {
        name
    }

    init(_ name: String, _ items: [[(String, Data)]], _ expected: CardKind) {
        self.name = name
        self.items = items
        self.expected = expected
    }
}

@MainActor
struct ClassifyTests {
    private func snapshot(of items: [[(String, Data)]]) throws -> PasteboardSnapshot {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map { representations in
            let item = NSPasteboardItem()
            for (type, data) in representations {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        })
        return try #require(PasteboardSnapshot(pasteboard: pasteboard))
    }

    @Test(arguments: [
        Case("one file", [[(fileURL, Data("file:///tmp/a.txt".utf8))]], .file),
        Case("multiple files", [
            [(fileURL, Data("file:///tmp/a.txt".utf8))],
            [(fileURL, Data("file:///tmp/b.txt".utf8))]
        ], .file),
        Case("file with image", [[("public.png", Data([1])), (fileURL, Data("file:///tmp/a.png".utf8))]], .file),
        Case("png", [[("public.png", Data([1]))]], .image),
        Case("tiff", [[("public.tiff", Data([1]))]], .image),
        Case("jpeg", [[("public.jpeg", Data([1]))]], .image),
        Case("heic", [[("public.heic", Data([1]))]], .image),
        Case("pdf", [[("com.adobe.pdf", Data([1]))]], .image),
        Case("image with text", [[("public.png", Data([1])), (plainText, Data("https://a.com".utf8))]], .image),
        Case("https", text("  https://example.com/a?b=c\n"), .link),
        Case("http", text("http://example.com"), .link),
        Case("mailto", text("mailto:someone@example.com"), .link),
        Case("ftp", text("ftp://example.com/file"), .link),
        Case("custom scheme", text("custom://x"), .link),
        Case("url with spaces", text("https://example.com/a b"), .text),
        Case("two urls", text("https://a.com\nhttps://b.com"), .text),
        Case("scheme without slashes", text("note:x"), .text),
        Case("http without host", text("http:example.com"), .text),
        Case("hash hex", text("#1A2B3C"), .color),
        Case("letter hex", text("1a2b3c"), .color),
        Case("digit hex with hash", text("#235442"), .color),
        Case("digits only", text("235442"), .text),
        Case("short hex", text("#FFF"), .text),
        Case("rgb", text("rgb(1, 2, 3)"), .text),
        Case("color name", text("red"), .text),
        Case("hex in sentence", text("the color is #1A2B3C"), .text),
        Case("8-digit hex", text("#1A2B3C4D"), .text),
        Case("plain text", text("hello"), .text),
        Case("rich text only", [[("public.rtf", Data([1]))]], .text),
        Case("rtfd only", [[("com.apple.flat-rtfd", Data([1]))]], .text),
        Case("rich hex", [[("public.rtf", Data([1])), (plainText, Data("#1A2B3C".utf8))]], .color),
        Case("unknown", [[("com.example.private", Data([1]))]], .unknown)
    ])
    private func classification(_ testCase: Case) throws {
        #expect(try classify(snapshot(of: testCase.items)) == testCase.expected)
    }
}
