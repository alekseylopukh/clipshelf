import AppKit
import Store
import SwiftUI

enum RichTextPreview {
    struct Luminance: Sendable, Equatable {
        let value: Double

        init?(_ color: NSColor) {
            guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
            let linear = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { component in
                let channel = Double(component)
                return channel <= 0.040_45 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            value = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
        }

        func contrastRatio(to other: Luminance) -> Double {
            (max(value, other.value) + 0.05) / (min(value, other.value) + 0.05)
        }
    }

    static let minimumContrast = 4.5
    static let maximumLength = 1000

    private static let richTypes: Set = [
        NSPasteboard.PasteboardType.rtf.rawValue, NSPasteboard.PasteboardType.rtfd.rawValue
    ]

    static func attributedString(
        from representations: [Representation],
        bodySize: CGFloat,
        background: Luminance
    ) -> AttributedString? {
        guard let representation = representations.first(where: { richTypes.contains($0.uti) }),
              let document = representation.uti == NSPasteboard.PasteboardType.rtf.rawValue
              ? NSAttributedString(rtf: representation.data, documentAttributes: nil)
              : NSAttributedString(rtfd: representation.data, documentAttributes: nil),
              document.length > 0
        else { return nil }
        let range = NSRange(location: 0, length: min(document.length, maximumLength))
        let scale = bodySize / (dominantFontSize(in: document, range: range) ?? bodySize)
        var result = AttributedString()
        document.enumerateAttributes(in: range) { attributes, runRange, _ in
            var run = AttributedString(document.attributedSubstring(from: runRange).string)
            if let font = attributes[.font] as? NSFont {
                let scaled = NSFont(descriptor: font.fontDescriptor, size: font.pointSize * scale) ?? font
                run.font = Font(scaled as CTFont)
            }
            if let color = attributes[.foregroundColor] as? NSColor,
               let luminance = Luminance(color),
               luminance.contrastRatio(to: background) >= minimumContrast
            {
                run.foregroundColor = Color(nsColor: color)
            }
            if let underline = attributes[.underlineStyle] as? Int, underline != 0 {
                run.underlineStyle = .single
            }
            if let strikethrough = attributes[.strikethroughStyle] as? Int, strikethrough != 0 {
                run.strikethroughStyle = .single
            }
            result.append(run)
        }
        return result
    }

    private static func dominantFontSize(in document: NSAttributedString, range: NSRange) -> CGFloat? {
        var lengths: [CGFloat: Int] = [:]
        document.enumerateAttribute(.font, in: range) { value, runRange, _ in
            if let font = value as? NSFont {
                lengths[font.pointSize, default: 0] += runRange.length
            }
        }
        return lengths.max { $0.value < $1.value }?.key
    }
}
