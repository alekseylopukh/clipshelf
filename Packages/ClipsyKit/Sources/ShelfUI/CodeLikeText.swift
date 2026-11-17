import Foundation

enum CodeLikeText {
    static func isCodeLike(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
        guard let first = lines.first else { return false }
        if lines.count == 1 {
            return hasStrongSignal(first)
        }
        let codeLines = lines.count { hasStrongSignal($0) || hasWeakSignal($0) }
        return codeLines * 2 >= lines.count && lines.contains(where: hasStrongSignal)
    }

    private static let lineEndings: [Character] = [";", "{", "}"]
    private static let linePrefixes = ["}", "]", "//", "/*", "#include", "#import", "#define", "#!", "$ ", "<?", "<!--"]
    private static let operators = ["=>", "->", "==", "!=", "&&", "||", "::", "+=", "-=", ":=", "</", "/>"]
    private static let keywords: Set = [
        "let", "var", "const", "import", "func", "def", "class", "struct", "enum", "fn", "return", "package", "using"
    ]
    private static let keywordFollowers: Set<Character> = ["=", "(", ")", "{", "}", "[", "]", ";", ":", "<", ">"]
    private static let sentenceEndings: [Character] = [".", "!", "?"]

    private static func hasStrongSignal(_ line: String) -> Bool {
        if isProse(line) {
            return false
        }
        if let last = line.last, lineEndings.contains(last) {
            return true
        }
        if linePrefixes.contains(where: line.hasPrefix) || operators.contains(where: line.contains) {
            return true
        }
        return startsWithKeyword(line)
    }

    private static func hasWeakSignal(_ line: String) -> Bool {
        if isProse(line) {
            return false
        }
        if line.hasPrefix("\""), line.contains("\":") {
            return true
        }
        if line.hasPrefix("<"), line.hasSuffix(">") {
            return true
        }
        return line.contains(/[A-Za-z_][A-Za-z0-9_.]*\(/) || line.contains(/^[A-Za-z_][A-Za-z0-9_.]*\s=\s/)
    }

    private static func startsWithKeyword(_ line: String) -> Bool {
        let words = line.split(separator: " ", omittingEmptySubsequences: true)
        guard words.count >= 2, keywords.contains(String(words[0])) else { return false }
        return words.count == 2 || line.contains(where: keywordFollowers.contains)
    }

    private static func isProse(_ line: String) -> Bool {
        guard let last = line.last, sentenceEndings.contains(last) else { return false }
        return line.split(separator: " ").count >= 4
    }
}
