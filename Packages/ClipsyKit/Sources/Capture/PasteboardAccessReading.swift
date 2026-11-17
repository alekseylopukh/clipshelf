import AppKit

public protocol PasteboardAccessReading {
    var accessBehavior: NSPasteboard.AccessBehavior { get }
}

extension NSPasteboard: PasteboardAccessReading {}
