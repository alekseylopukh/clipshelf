import DesignSystem
import Foundation
import SwiftUI

enum SearchHighlight {
    static func text(_ string: String, matches: [Range<String.Index>]) -> AttributedString? {
        guard !matches.isEmpty else { return nil }
        var text = AttributedString(string)
        for match in matches {
            guard let range = Range(NSRange(match, in: string), in: text) else { continue }
            text[range].backgroundColor = Color(nsColor: DesignTokens.searchHighlightFill)
            text[range].foregroundColor = Color(nsColor: DesignTokens.searchHighlightText)
        }
        return text
    }
}
