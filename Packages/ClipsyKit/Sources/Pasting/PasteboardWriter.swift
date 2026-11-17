import AppKit
import Store

@MainActor
public final class PasteboardWriter {
    private let pasteboard: NSPasteboard
    private var ownWriteChangeCount: Int?

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    /// `representations` must be in item and type order; returns the pasteboard's change count after the write
    @discardableResult
    public func write(_ representations: [Representation], plainTextOnly: Bool) -> Int {
        let plain = representations.filter { $0.uti == NSPasteboard.PasteboardType.string.rawValue }
        let written = plainTextOnly && plain.isEmpty == false ? plain : representations

        var items: [NSPasteboardItem] = []
        var itemIndex: Int?
        for representation in written {
            if representation.itemIndex != itemIndex {
                items.append(NSPasteboardItem())
                itemIndex = representation.itemIndex
            }
            items.last?.setData(representation.data, forType: NSPasteboard.PasteboardType(representation.uti))
        }
        if items.isEmpty {
            items.append(NSPasteboardItem())
        }
        items[0].setData(Data(), forType: NSPasteboard.PasteboardType(PasteboardMarker.ownWrite))

        pasteboard.clearContents()
        pasteboard.writeObjects(items)
        let changeCount = pasteboard.changeCount
        ownWriteChangeCount = changeCount
        return changeCount
    }

    public func isOwnWrite(_ changeCount: Int) -> Bool {
        changeCount == ownWriteChangeCount
    }
}
