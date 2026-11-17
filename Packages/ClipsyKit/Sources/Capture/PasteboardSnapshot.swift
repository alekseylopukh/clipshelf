import AppKit
import Store

public struct PasteboardSnapshot: Sendable, Equatable {
    public static let sizeCap = 50_000_000

    static let junkTypes = Set([
        PasteboardMarker.ownWrite,
        "org.nspasteboard.source",
        "com.microsoft.ObjectLink",
        "com.microsoft.Link-Source",
        "com.microsoft.DataObject",
        "com.microsoft.ole.source"
    ].map { NSPasteboard.PasteboardType($0) })

    /// items that lose every type are dropped and the rest renumbered from 0
    public let representations: [Representation]

    public init?(pasteboard: some PasteboardReading) {
        var representations: [Representation] = []
        var itemIndex = 0
        for item in pasteboard.items {
            let kept = item.types
                .filter { Self.junkTypes.contains($0) == false }
                .compactMap { type -> Representation? in
                    guard let data = item.data(forType: type), data.count <= Self.sizeCap else { return nil }
                    return Representation(itemIndex: itemIndex, uti: type.rawValue, data: data)
                }
            guard kept.isEmpty == false else { continue }
            representations += kept
            itemIndex += 1
        }
        guard representations.isEmpty == false else { return nil }
        self.representations = representations
    }
}
