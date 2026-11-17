import AppKit
import Store
import UniformTypeIdentifiers

@MainActor
enum CardDragItems {
    static func writers(for contents: [CardDragContent]) -> [any NSPasteboardWriting] {
        contents.flatMap { content in
            content.items.enumerated().map { index, representations -> any NSPasteboardWriting in
                var data = representations.map { (NSPasteboard.PasteboardType($0.uti), $0.data) }
                data.append((NSPasteboard.PasteboardType(UTType.clipsyCardReference.identifier), content.reference))
                if index == 0, let imageFile = content.imageFile {
                    return ImageFilePromise(file: imageFile, data: data)
                }
                let item = NSPasteboardItem()
                for (type, value) in data where item.data(forType: type) == nil {
                    item.setData(value, forType: type)
                }
                return item
            }
        }
    }
}
