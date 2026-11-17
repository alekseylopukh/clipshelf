import AppKit
import Store
import Testing
@testable import Pasting

@MainActor
struct PasteboardWriterTests {
    private static let marker = NSPasteboard.PasteboardType(PasteboardMarker.ownWrite)

    private let pasteboard = NSPasteboard.withUniqueName()
    private let representations = [
        Representation(itemIndex: 0, uti: "public.rtf", data: Data([1])),
        Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data([2])),
        Representation(itemIndex: 1, uti: "public.png", data: Data([3])),
        Representation(itemIndex: 2, uti: "public.html", data: Data([4])),
        Representation(itemIndex: 2, uti: "public.utf8-plain-text", data: Data([5]))
    ]

    private var written: [Representation] {
        (pasteboard.pasteboardItems ?? []).enumerated().flatMap { index, item in
            item.types.filter { $0 != Self.marker }.compactMap { type in
                item.data(forType: type).map { Representation(itemIndex: index, uti: type.rawValue, data: $0) }
            }
        }
    }

    @Test func `writes all representations in order`() {
        PasteboardWriter(pasteboard: pasteboard).write(representations, plainTextOnly: false)
        defer { pasteboard.releaseGlobally() }
        #expect(written == representations)
    }

    @Test func `plain writes only string`() {
        PasteboardWriter(pasteboard: pasteboard).write(representations, plainTextOnly: true)
        defer { pasteboard.releaseGlobally() }
        #expect(written == [
            Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data([2])),
            Representation(itemIndex: 1, uti: "public.utf8-plain-text", data: Data([5]))
        ])
    }

    @Test func `plain without a string writes all representations`() {
        let image = [Representation(itemIndex: 0, uti: "public.png", data: Data([3]))]
        PasteboardWriter(pasteboard: pasteboard).write(image, plainTextOnly: true)
        defer { pasteboard.releaseGlobally() }
        #expect(written == image)
    }

    @Test(arguments: [false, true])
    func `marker is present`(plainTextOnly: Bool) throws {
        PasteboardWriter(pasteboard: pasteboard).write(representations, plainTextOnly: plainTextOnly)
        defer { pasteboard.releaseGlobally() }
        let first = try #require(pasteboard.pasteboardItems?.first)
        #expect(first.types.contains(Self.marker))
    }

    @Test func `ledger matches change count`() {
        let writer = PasteboardWriter(pasteboard: pasteboard)
        defer { pasteboard.releaseGlobally() }
        let changeCount = writer.write(representations, plainTextOnly: false)
        #expect(changeCount == pasteboard.changeCount)
        #expect(writer.isOwnWrite(pasteboard.changeCount))

        pasteboard.clearContents()
        #expect(writer.isOwnWrite(pasteboard.changeCount) == false)
    }
}
