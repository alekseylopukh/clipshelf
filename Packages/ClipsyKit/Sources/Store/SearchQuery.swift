import Foundation

struct SearchQuery {
    let terms: [String]

    init(_ text: String) {
        terms = Self.words(in: text).map { String(text[$0]) }
    }

    var ftsPattern: String? {
        terms.isEmpty ? nil : terms.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    func matches(in text: String) -> [Range<String.Index>] {
        Self.words(in: text).compactMap { word in
            terms
                .compactMap {
                    text.range(
                        of: $0,
                        options: [.anchored, .caseInsensitive, .diacriticInsensitive],
                        range: word
                    )
                }
                .max { $0.upperBound < $1.upperBound }
        }
    }

    /// mirrors the unicode61 tokenizer: a token is a run of letters and numbers
    private static func words(in text: String) -> [Range<String.Index>] {
        var words: [Range<String.Index>] = []
        var start: String.Index?
        for index in text.indices {
            let character = text[index]
            if character.isLetter || character.isNumber {
                if start == nil {
                    start = index
                }
            } else if let wordStart = start {
                words.append(wordStart ..< index)
                start = nil
            }
        }
        if let start {
            words.append(start ..< text.endIndex)
        }
        return words
    }
}
