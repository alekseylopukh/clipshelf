import AppKit
import ImageIO
import Store
import Testing
import UniformTypeIdentifiers
@testable import Capture

private struct FakeItem: PasteboardItemReading {
    let representations: [(type: String, data: Data)]

    var types: [NSPasteboard.PasteboardType] {
        representations.map { NSPasteboard.PasteboardType($0.type) }
    }

    func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        representations.first { $0.type == type.rawValue }?.data
    }
}

private struct FakePasteboard: PasteboardReading {
    let changeCount = 1
    let items: [any PasteboardItemReading]
}

private let plainText = "public.utf8-plain-text"
private let richText = "public.rtf"
private let fileURL = "public.file-url"
private let textEdit = SourceApp(bundleID: "com.example.editor", name: "Editor")
private let notes = SourceApp(bundleID: "com.example.notes", name: "Notes")

private func card(_ items: [[(type: String, data: Data)]], from app: SourceApp = textEdit) throws -> NewCard {
    let pasteboard = FakePasteboard(items: items.map(FakeItem.init))
    return try NewCard(snapshot: #require(PasteboardSnapshot(pasteboard: pasteboard)), sourceApp: app)
}

private func metadata(of card: NewCard) throws -> CardMetadata {
    let json = try #require(card.metadata)
    return try JSONDecoder().decode(CardMetadata.self, from: Data(json.utf8))
}

private func png(width: Int, height: Int) throws -> Data {
    let context = try #require(CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    let image = try #require(context.makeImage())
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    try #require(CGImageDestinationFinalize(destination))
    return data as Data
}

struct NewCardSnapshotTests {
    @Test func `same text from two apps same hash`() throws {
        let first = try card([[(plainText, Data("hello".utf8))]], from: textEdit)
        let second = try card([[(plainText, Data("hello".utf8))]], from: notes)
        #expect(first.contentHash == second.contentHash)
        #expect(first.contentHash.count == 32)
    }

    @Test func `rich and plain differ`() throws {
        let plain = try card([[(plainText, Data("hello".utf8))]])
        let rich = try card([[(richText, Data(#"{\rtf1 hello}"#.utf8)), (plainText, Data("hello".utf8))]])
        #expect(plain.contentHash != rich.contentHash)
    }

    @Test func `type order does not change hash`() throws {
        let first = try card([[(richText, Data([1])), (plainText, Data([2]))]])
        let second = try card([[(plainText, Data([2])), (richText, Data([1]))]])
        #expect(first.contentHash == second.contentHash)
    }

    @Test func `field boundaries change hash`() {
        let first = contentHash(of: [Representation(itemIndex: 0, uti: "a.b", data: Data("c".utf8))])
        let second = contentHash(of: [Representation(itemIndex: 0, uti: "a", data: Data(".bc".utf8))])
        #expect(first != second)
    }

    @Test func `image metadata has pixel size`() throws {
        let card = try card([[("public.png", png(width: 3, height: 2))]])
        #expect(card.kind == .image)
        #expect(card.previewText == nil)
        let metadata = try metadata(of: card)
        #expect(metadata.pixelWidth == 3)
        #expect(metadata.pixelHeight == 2)
    }

    @Test func `file metadata has names`() throws {
        let card = try card([
            [(fileURL, Data("file:///nonexistent/a%20b.txt".utf8))],
            [(fileURL, Data("file:///nonexistent/c.pdf".utf8))]
        ])
        #expect(card.kind == .file)
        #expect(card.fileNames == ["a b.txt", "c.pdf"])
        let metadata = try metadata(of: card)
        #expect(metadata.fileNames == ["a b.txt", "c.pdf"])
        #expect(metadata.totalFileSize == nil)
    }

    @Test func `file metadata has total size`() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let urls = [directory.appending(path: "a"), directory.appending(path: "b")]
        try Data(count: 10).write(to: urls[0])
        try Data(count: 5).write(to: urls[1])

        let card = try card(urls.map { [(fileURL, $0.dataRepresentation)] })
        #expect(try metadata(of: card).totalFileSize == 15)
    }

    @Test func `text has preview and counts`() throws {
        let text = "one two\nthree\n" + String(repeating: "x", count: 1100)
        let card = try card([[(plainText, Data(text.utf8))]])
        #expect(card.kind == .text)
        #expect(card.previewText == String(text.prefix(1000)))
        #expect(card.searchBody == text)
        let metadata = try metadata(of: card)
        #expect(metadata.characterCount == text.count)
        #expect(metadata.wordCount == 4)
        #expect(metadata.lineCount == 3)
    }

    @Test func `short text has no separate search body`() throws {
        let card = try card([[(plainText, Data("hello".utf8))]])
        #expect(card.previewText == "hello")
        #expect(card.searchBody == nil)
    }

    @Test func `rich only text has preview`() throws {
        let rtf = try #require(NSAttributedString(string: "styled").rtf(from: NSRange(location: 0, length: 6)))
        let card = try card([[(richText, rtf)]])
        #expect(card.previewText == "styled")
        #expect(try metadata(of: card).characterCount == 6)
    }

    @Test func `link metadata has URL`() throws {
        let card = try card([[(plainText, Data("  https://example.com/a\n".utf8))]])
        #expect(card.kind == .link)
        #expect(card.url == "https://example.com/a")
        #expect(card.previewText == "https://example.com/a")
        #expect(try metadata(of: card).url == "https://example.com/a")
    }

    @Test func `color metadata keeps copied value`() throws {
        let card = try card([[(plainText, Data(" 1a2b3c ".utf8))]])
        #expect(card.kind == .color)
        #expect(try metadata(of: card).color == "1a2b3c")
    }

    @Test func `unknown metadata has type identifier`() throws {
        let card = try card([[("com.example.private", Data([1]))]])
        #expect(card.kind == .unknown)
        #expect(card.previewText == nil)
        #expect(try metadata(of: card).typeIdentifier == "com.example.private")
    }
}
