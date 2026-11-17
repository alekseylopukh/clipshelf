import Foundation

public struct TextCounts: Sendable, Equatable {
    public var characters: Int
    public var words: Int
    public var lines: Int

    public init(_ text: String) {
        characters = text.count
        var words = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            words += 1
        }
        self.words = words
        var lines = 0
        text.enumerateLines { _, _ in
            lines += 1
        }
        self.lines = lines
    }
}
