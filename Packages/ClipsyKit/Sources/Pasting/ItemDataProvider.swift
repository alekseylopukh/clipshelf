import AppKit
import Store

final class ItemDataProvider: NSObject, NSPasteboardItemDataProvider, Sendable {
    private let data: [NSPasteboard.PasteboardType: Data]
    private let onRead: @Sendable () -> Void

    init(representations: [Representation], onRead: @escaping @Sendable () -> Void) {
        data = Dictionary(
            representations.map { (NSPasteboard.PasteboardType($0.uti), $0.data) },
            uniquingKeysWith: { first, _ in first }
        )
        self.onRead = onRead
    }

    func pasteboard(
        _ pasteboard: NSPasteboard?,
        item: NSPasteboardItem,
        provideDataForType type: NSPasteboard.PasteboardType
    ) {
        guard let value = data[type] else { return }
        item.setData(value, forType: type)
        onRead()
    }
}
