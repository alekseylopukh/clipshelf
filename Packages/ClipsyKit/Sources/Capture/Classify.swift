import AppKit
import Store
import UniformTypeIdentifiers

func classify(_ snapshot: PasteboardSnapshot) -> CardKind {
    let types = snapshot.representations.compactMap { UTType($0.uti) }
    if types.contains(where: { $0.conforms(to: .fileURL) }) {
        return .file
    }
    if types.contains(where: { $0.conforms(to: .image) || $0.conforms(to: .pdf) }) {
        return .image
    }
    if let plainText = snapshot.representations
        .first(where: { $0.uti == NSPasteboard.PasteboardType.string.rawValue })
        .flatMap({ String(data: $0.data, encoding: .utf8) })
    {
        if isLink(plainText) {
            return .link
        }
        if HexColor(copiedText: plainText) != nil {
            return .color
        }
    }
    if types.contains(where: { $0.conforms(to: .text) || $0.conforms(to: .flatRTFD) }) {
        return .text
    }
    return .unknown
}

private func isLink(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.contains(where: \.isWhitespace) == false,
          let url = URL(string: trimmed),
          let scheme = url.scheme?.lowercased() else { return false }
    let rest = trimmed.dropFirst(scheme.count + 1)
    switch scheme {
    case "http", "https", "ftp":
        return url.host()?.isEmpty == false
    case "mailto":
        return rest.isEmpty == false
    default:
        return rest.hasPrefix("//") && rest.count > 2
    }
}
