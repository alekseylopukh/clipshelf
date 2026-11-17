import AppKit
import UniformTypeIdentifiers

/// an image card's drag item: the card's own types, plus a PNG file for apps such as Finder that take files
final class ImageFilePromise: NSFilePromiseProvider, NSFilePromiseProviderDelegate {
    private let file: CardDragContent.ImageFile
    private let data: [(type: NSPasteboard.PasteboardType, value: Data)]

    init(file: CardDragContent.ImageFile, data: [(NSPasteboard.PasteboardType, Data)]) {
        self.file = file
        self.data = data.map { (type: $0.0, value: $0.1) }
        super.init()
        fileType = UTType.png.identifier
        delegate = self
    }

    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        let own = data.map(\.type)
        return own + super.writableTypes(for: pasteboard).filter { !own.contains($0) }
    }

    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        data.first { $0.type == type }?.value ?? super.pasteboardPropertyList(forType: type)
    }

    func filePromiseProvider(_: NSFilePromiseProvider, fileNameForType _: String) -> String {
        file.name
    }

    nonisolated func filePromiseProvider(_: NSFilePromiseProvider, writePromiseTo url: URL) async throws {
        try file.png.write(to: url, options: .withoutOverwriting)
    }
}
