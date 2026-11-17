import AppKit
import CoreTransferable
import ImageIO
import Pasting
import Store
import Testing
import UniformTypeIdentifiers
@testable import ShelfUI

@MainActor
struct CardDragItemsTests {
    private typealias Item = [NSPasteboard.PasteboardType: Data]

    private static let referenceType = NSPasteboard.PasteboardType(UTType.clipsyCardReference.identifier)

    private static func card(_ id: Int64, _ kind: CardKind, title: String? = nil) -> CardSummary {
        CardSummary(id: id, kind: kind, title: title, createdAt: Date(timeIntervalSince1970: 0))
    }

    private static func items(on pasteboard: NSPasteboard, types: (NSPasteboardItem) -> [NSPasteboard.PasteboardType])
        -> [Item]
    {
        (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: types(item).compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    private static func pasteItems(_ representations: [Representation]) -> [Item] {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        PasteboardWriter(pasteboard: pasteboard).write(representations, plainTextOnly: false)
        let types = representations.map { NSPasteboard.PasteboardType($0.uti) }
        return items(on: pasteboard) { $0.types.filter(types.contains) }
    }

    private static func dragItems(_ contents: [CardDragContent], types: [NSPasteboard.PasteboardType]) -> [Item] {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.writeObjects(CardDragItems.writers(for: contents))
        return items(on: pasteboard) { item in item.types.filter(types.contains) }
    }

    private static func pngImage() throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func `drag items match paste representations`() async throws {
        let text = [
            Representation(itemIndex: 0, uti: UTType.utf8PlainText.identifier, data: Data("plan".utf8)),
            Representation(itemIndex: 0, uti: UTType.rtf.identifier, data: Data("{\\rtf1 plan}".utf8))
        ]
        let files = [
            Representation(
                itemIndex: 0,
                uti: UTType.fileURL.identifier,
                data: URL(filePath: "/tmp/a.txt").dataRepresentation
            ),
            Representation(
                itemIndex: 1,
                uti: UTType.fileURL.identifier,
                data: URL(filePath: "/tmp/b.txt").dataRepresentation
            )
        ]
        let contents = try await [
            CardDragContent.make(for: Self.card(1, .text), representations: text),
            CardDragContent.make(for: Self.card(2, .file), representations: files)
        ]
        let types = (text + files).map { NSPasteboard.PasteboardType($0.uti) }

        let dragged = Self.dragItems(contents, types: types)

        #expect(dragged == Self.pasteItems(text) + Self.pasteItems(files))
    }

    @Test func `every dragged item carries its card reference`() async throws {
        let files = [
            Representation(
                itemIndex: 0,
                uti: UTType.fileURL.identifier,
                data: URL(filePath: "/tmp/a.txt").dataRepresentation
            ),
            Representation(
                itemIndex: 1,
                uti: UTType.fileURL.identifier,
                data: URL(filePath: "/tmp/b.txt").dataRepresentation
            )
        ]
        let content = try await CardDragContent.make(for: Self.card(7, .file), representations: files)

        let references = Self.dragItems([content], types: [Self.referenceType]).compactMap { $0[Self.referenceType] }

        #expect(references.count == 2)
        for data in references {
            let reference = try await CardReference(importing: data, contentType: .clipsyCardReference)
            #expect(reference.cardID == 7)
        }
    }

    @Test func `image card also promises a png file named after its title`() async throws {
        let png = try Self.pngImage()
        let image = [Representation(itemIndex: 0, uti: UTType.png.identifier, data: png)]

        let content = try await CardDragContent.make(
            for: Self.card(3, .image, title: "Plan/Draft"),
            representations: image
        )
        let dragged = Self.dragItems([content], types: [.png, Self.referenceType])

        #expect(content.imageFile == CardDragContent.ImageFile(name: "Plan-Draft.png", png: png))
        #expect(dragged.map { $0[.png] } == [png])
        #expect(CardDragItems.writers(for: [content]).first is NSFilePromiseProvider)
    }

    @Test func `tiff image is converted for the png file`() async throws {
        let source = try #require(CGImageSourceCreateWithData(Self.pngImage() as CFData, nil))
        let cgImage = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let tiff = try #require(NSBitmapImageRep(cgImage: cgImage).tiffRepresentation)

        let content = try await CardDragContent.make(
            for: Self.card(4, .image),
            representations: [Representation(itemIndex: 0, uti: UTType.tiff.identifier, data: tiff)]
        )

        let file = try #require(content.imageFile)
        #expect(file.name == "Image.png")
        let converted = try #require(CGImageSourceCreateWithData(file.png as CFData, nil))
        #expect(CGImageSourceGetType(converted) as String? == UTType.png.identifier)
    }

    @Test func `text card promises no file`() async throws {
        let text = [Representation(itemIndex: 0, uti: UTType.utf8PlainText.identifier, data: Data("plan".utf8))]

        let content = try await CardDragContent.make(for: Self.card(5, .text), representations: text)

        #expect(content.imageFile == nil)
        #expect(CardDragItems.writers(for: [content]).first is NSPasteboardItem)
    }

    @Test func `repeated references collapse in drop order`() {
        let references = [3, 1, 3, 2, 1].map { CardReference(cardID: $0) }

        #expect(references.cardIDs == [3, 1, 2])
    }
}
