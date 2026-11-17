import AppKit
import Store

@MainActor
public final class PasteboardWriter {
    private let pasteboard: NSPasteboard
    private var ownWriteChangeCount: Int?
    private var dataProviders: [ItemDataProvider] = []

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    /// `representations` must be in item and type order; returns the pasteboard's change count after the write
    @discardableResult
    public func write(_ representations: [Representation], plainTextOnly: Bool) -> Int {
        write(representations, plainTextOnly: plainTextOnly, onRead: nil)
    }

    /// like `write`, but the data is handed over only when a reader asks for it; `onRead` runs on every such request
    @discardableResult
    public func writeLazily(
        _ representations: [Representation],
        plainTextOnly: Bool,
        onRead: @escaping @Sendable () -> Void
    ) -> Int {
        write(representations, plainTextOnly: plainTextOnly, onRead: onRead)
    }

    public func isOwnWrite(_ changeCount: Int) -> Bool {
        changeCount == ownWriteChangeCount
    }

    var holdsLastWrite: Bool {
        pasteboard.changeCount == ownWriteChangeCount
    }

    private func write(
        _ representations: [Representation],
        plainTextOnly: Bool,
        onRead: (@Sendable () -> Void)?
    ) -> Int {
        let plain = representations.filter { $0.uti == NSPasteboard.PasteboardType.string.rawValue }
        let written = plainTextOnly && plain.isEmpty == false ? plain : representations

        var groups: [[Representation]] = []
        var itemIndex: Int?
        for representation in written {
            if representation.itemIndex != itemIndex {
                groups.append([])
                itemIndex = representation.itemIndex
            }
            groups[groups.count - 1].append(representation)
        }

        dataProviders = []
        var items = groups.map { group in
            let item = NSPasteboardItem()
            if let onRead {
                let provider = ItemDataProvider(representations: group, onRead: onRead)
                item.setDataProvider(provider, forTypes: group.map { NSPasteboard.PasteboardType($0.uti) })
                dataProviders.append(provider)
            } else {
                for representation in group {
                    item.setData(representation.data, forType: NSPasteboard.PasteboardType(representation.uti))
                }
            }
            return item
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
}
