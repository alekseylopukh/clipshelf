import AppKit
import ImageIO
import Store
import UniformTypeIdentifiers

extension NewCard {
    static let previewLength = 1000

    public init(snapshot: PasteboardSnapshot, sourceApp: SourceApp) {
        let representations = snapshot.representations
        let kind = classify(snapshot)
        var text: String?
        var url: String?
        var fileNames: [String] = []
        var metadata = CardMetadata()

        switch kind {
        case .text:
            text = plainString(in: representations) ?? richString(in: representations)
            if let text {
                metadata.characterCount = text.count
                metadata.wordCount = wordCount(of: text)
                metadata.lineCount = lineCount(of: text)
            }
        case .link:
            url = plainString(in: representations)?.trimmingCharacters(in: .whitespacesAndNewlines)
            text = url
            metadata.url = url
        case .color:
            text = plainString(in: representations)?.trimmingCharacters(in: .whitespacesAndNewlines)
            metadata.color = text
        case .image:
            if let size = pixelSize(in: representations) {
                metadata.pixelWidth = size.width
                metadata.pixelHeight = size.height
            }
        case .file:
            let urls = fileURLs(in: representations)
            fileNames = urls.map(\.lastPathComponent)
            metadata.fileNames = fileNames
            metadata.totalFileSize = totalFileSize(of: urls)
        case .unknown:
            metadata.typeIdentifier = representations.first?.uti
        }

        let previewText = text.map { String($0.prefix(Self.previewLength)) }
        self.init(
            kind: kind,
            representations: representations,
            contentHash: Capture.contentHash(of: representations),
            previewText: previewText,
            metadata: encoded(metadata),
            sourceApp: sourceApp,
            searchBody: text == previewText ? nil : text,
            url: url,
            fileNames: fileNames
        )
    }
}

private func plainString(in representations: [Representation]) -> String? {
    representations
        .first { $0.uti == NSPasteboard.PasteboardType.string.rawValue }
        .flatMap { String(data: $0.data, encoding: .utf8) }
}

private func richString(in representations: [Representation]) -> String? {
    for representation in representations {
        let attributed: NSAttributedString? = switch representation.uti {
        case NSPasteboard.PasteboardType.rtf.rawValue:
            NSAttributedString(rtf: representation.data, documentAttributes: nil)
        case NSPasteboard.PasteboardType.rtfd.rawValue:
            NSAttributedString(rtfd: representation.data, documentAttributes: nil)
        default:
            nil
        }
        if let attributed {
            return attributed.string
        }
    }
    return nil
}

private func wordCount(of text: String) -> Int {
    var count = 0
    text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
        count += 1
    }
    return count
}

private func lineCount(of text: String) -> Int {
    var count = 0
    text.enumerateLines { _, _ in
        count += 1
    }
    return count
}

private func pixelSize(in representations: [Representation]) -> (width: Int, height: Int)? {
    for representation in representations where UTType(representation.uti)?.conforms(to: .image) == true {
        guard let source = CGImageSourceCreateWithData(representation.data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { continue }
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32
        let isRotated = orientation.flatMap { CGImagePropertyOrientation(rawValue: $0) }.map {
            [.left, .leftMirrored, .right, .rightMirrored].contains($0)
        } ?? false
        return isRotated ? (height, width) : (width, height)
    }
    return nil
}

private func fileURLs(in representations: [Representation]) -> [URL] {
    representations
        .filter { $0.uti == NSPasteboard.PasteboardType.fileURL.rawValue }
        .compactMap { URL(dataRepresentation: $0.data, relativeTo: nil) }
        .map { ($0 as NSURL).filePathURL ?? $0 }
}

private func totalFileSize(of urls: [URL]) -> Int? {
    var total = 0
    for url in urls {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .totalFileSizeKey]),
              values.isRegularFile == true,
              let size = values.totalFileSize else { return nil }
        total += size
    }
    return total
}

private func encoded(_ metadata: CardMetadata) -> String? {
    guard metadata != CardMetadata() else { return nil }
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    guard let data = try? encoder.encode(metadata), let json = String(bytes: data, encoding: .utf8) else {
        fatalError("CardMetadata holds only strings and integers, which always encode as UTF-8 JSON")
    }
    return json
}
