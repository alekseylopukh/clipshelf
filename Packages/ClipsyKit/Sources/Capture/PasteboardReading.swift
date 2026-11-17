import AppKit

public protocol PasteboardReading {
    var changeCount: Int { get }
    var items: [any PasteboardItemReading] { get }
}

public protocol PasteboardItemReading {
    var types: [NSPasteboard.PasteboardType] { get }
    func data(forType type: NSPasteboard.PasteboardType) -> Data?
}

extension NSPasteboard: PasteboardReading {
    public var items: [any PasteboardItemReading] {
        pasteboardItems ?? []
    }
}

extension NSPasteboardItem: PasteboardItemReading {}
