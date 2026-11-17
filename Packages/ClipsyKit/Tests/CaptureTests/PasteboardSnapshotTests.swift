import AppKit
import Store
import Testing
@testable import Capture

@MainActor
struct PasteboardSnapshotTests {
    private typealias Item = [(type: String, data: Data)]

    private func snapshot(of items: [Item]) -> PasteboardSnapshot? {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map { representations in
            let item = NSPasteboardItem()
            for representation in representations {
                item.setData(representation.data, forType: NSPasteboard.PasteboardType(representation.type))
            }
            return item
        })
        return PasteboardSnapshot(pasteboard: pasteboard)
    }

    @Test func `reads all items and types in order`() throws {
        let snapshot = try #require(snapshot(of: [
            [("public.rtf", Data([1])), ("public.utf8-plain-text", Data([2]))],
            [("public.png", Data([3]))],
            [("public.html", Data([4])), ("public.file-url", Data([5]))]
        ]))
        #expect(snapshot.representations == [
            Representation(itemIndex: 0, uti: "public.rtf", data: Data([1])),
            Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data([2])),
            Representation(itemIndex: 1, uti: "public.png", data: Data([3])),
            Representation(itemIndex: 2, uti: "public.html", data: Data([4])),
            Representation(itemIndex: 2, uti: "public.file-url", data: Data([5]))
        ])
    }

    @Test(arguments: PasteboardSnapshot.junkTypes.map(\.rawValue))
    func `drops junk types`(junkType: String) throws {
        let snapshot = try #require(snapshot(of: [
            [(junkType, Data([1])), ("public.utf8-plain-text", Data([2]))],
            [(junkType, Data([3]))],
            [("public.png", Data([4]))]
        ]))
        #expect(snapshot.representations == [
            Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data([2])),
            Representation(itemIndex: 1, uti: "public.png", data: Data([4]))
        ])
    }

    @Test func `drops oversized representation`() throws {
        let snapshot = try #require(snapshot(of: [[
            ("public.tiff", Data(count: PasteboardSnapshot.sizeCap + 1)),
            ("public.png", Data(count: PasteboardSnapshot.sizeCap))
        ]]))
        #expect(snapshot.representations.map(\.uti) == ["public.png"])
    }

    @Test func `empty after filtering is nil`() {
        #expect(snapshot(of: [[(PasteboardMarker.ownWrite, Data([1])), ("org.nspasteboard.source", Data([2]))]]) == nil)
        #expect(snapshot(of: []) == nil)
    }
}
