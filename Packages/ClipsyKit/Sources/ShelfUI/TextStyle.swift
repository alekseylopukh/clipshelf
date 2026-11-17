import AppKit
import SwiftUI

enum TextStyle: CaseIterable, Hashable {
    case bold
    case italic
    case underline
    case strikethrough

    var title: LocalizedStringKey {
        switch self {
        case .bold: "Bold"
        case .italic: "Italic"
        case .underline: "Underline"
        case .strikethrough: "Strikethrough"
        }
    }

    var systemImage: String {
        switch self {
        case .bold: "bold"
        case .italic: "italic"
        case .underline: "underline"
        case .strikethrough: "strikethrough"
        }
    }

    var shortcut: KeyboardShortcut? {
        switch self {
        case .bold: KeyboardShortcut("b")
        case .italic: KeyboardShortcut("i")
        case .underline: KeyboardShortcut("u")
        case .strikethrough: nil
        }
    }

    func isApplied(in attributes: [NSAttributedString.Key: Any]) -> Bool {
        switch self {
        case .bold:
            (attributes[.font] as? NSFont)?.fontDescriptor.symbolicTraits.contains(.bold) ?? false
        case .italic:
            (attributes[.font] as? NSFont)?.fontDescriptor.symbolicTraits.contains(.italic) ?? false
        case .underline:
            (attributes[.underlineStyle] as? Int ?? 0) != 0
        case .strikethrough:
            (attributes[.strikethroughStyle] as? Int ?? 0) != 0
        }
    }

    @MainActor
    func setting(
        _ isApplied: Bool,
        in attributes: [NSAttributedString.Key: Any],
        defaultFont: NSFont
    ) -> [NSAttributedString.Key: Any] {
        var attributes = attributes
        switch self {
        case .bold, .italic:
            let trait: NSFontTraitMask = self == .bold ? .boldFontMask : .italicFontMask
            let font = attributes[.font] as? NSFont ?? defaultFont
            let manager = NSFontManager.shared
            attributes[.font] = isApplied
                ? manager.convert(font, toHaveTrait: trait)
                : manager.convert(font, toNotHaveTrait: trait)
        case .underline:
            attributes[.underlineStyle] = isApplied ? NSUnderlineStyle.single.rawValue : nil
        case .strikethrough:
            attributes[.strikethroughStyle] = isApplied ? NSUnderlineStyle.single.rawValue : nil
        }
        return attributes
    }
}
