import AppKit
import Store

enum TextCardContent {
    private static let plainType = NSPasteboard.PasteboardType.string.rawValue
    private static let rtfType = NSPasteboard.PasteboardType.rtf.rawValue
    private static let rtfdType = NSPasteboard.PasteboardType.rtfd.rawValue

    static func isRich(_ representations: [Representation]) -> Bool {
        representations.contains { $0.uti == rtfType || $0.uti == rtfdType }
    }

    static func attributedString(from representations: [Representation], font: NSFont) -> NSAttributedString {
        for uti in [rtfdType, rtfType] {
            guard let data = representations.first(where: { $0.uti == uti })?.data else { continue }
            let rich = uti == rtfdType
                ? NSAttributedString(rtfd: data, documentAttributes: nil)
                : NSAttributedString(rtf: data, documentAttributes: nil)
            if let rich {
                return rich
            }
        }
        let plain = representations.first { $0.uti == plainType }.flatMap { String(data: $0.data, encoding: .utf8) }
        return NSAttributedString(string: plain ?? "", attributes: [.font: font])
    }

    static func representations(of text: NSAttributedString, rich: Bool) throws -> [Representation] {
        var representations: [Representation] = []
        let range = NSRange(location: 0, length: text.length)
        if rich {
            let hasAttachments = text.containsAttachments(in: range)
            let type: NSAttributedString.DocumentType = hasAttachments ? .rtfd : .rtf
            let data = try text.data(from: range, documentAttributes: [.documentType: type])
            representations.append(Representation(itemIndex: 0, uti: hasAttachments ? rtfdType : rtfType, data: data))
        }
        representations.append(Representation(itemIndex: 0, uti: plainType, data: Data(text.string.utf8)))
        return representations
    }

    static func hasStyles(_ text: NSAttributedString) -> Bool {
        var found = false
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, _, stop in
            if TextStyle.allCases.contains(where: { $0.isApplied(in: attributes) }) {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}
