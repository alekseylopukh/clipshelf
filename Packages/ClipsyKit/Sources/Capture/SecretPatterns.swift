import Foundation

enum SecretPatterns {
    private static let keyword =
        "(?:password|passwd|passphrase|passcode|secret|token|api[_-]?key|private[_-]?key|access[_-]?key|secret[_-]?key)"
    private static let separator = #"["']?\s*(?::=|=>|[:=])\s*"#

    private static let patterns: [NSRegularExpression] = [
        keyword + separator + #"(["'`])(?=[^"'`\s]*[^A-Za-z"'`\s])[^"'`\s]{6,}\1"#,
        keyword + separator + #"(?=[^\s"'`,;()]*[A-Za-z])(?=[^\s"'`,;()]*[0-9])[^\s"'`,;()$@]{8,}(?=[\s,;]|$)"#,
        #"(?m)^[ \t]*(?:export[ \t]+)?[A-Z0-9_]*(?-i:PASSWORD|PASSWD|PASSPHRASE|PASSCODE|SECRET|TOKEN|API_?KEY|PRIVATE_?KEY|ACCESS_?KEY|SECRET_?KEY)[ \t]*=[ \t]*(?!\$)\S+"#,
        #"\beyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]*"#,
        #"\bgh[pousr]_[A-Za-z0-9]{36,}"#,
        #"\bgithub_pat_[A-Za-z0-9_]{22,}"#,
        #"\bxox[abeoprs]-[A-Za-z0-9-]{10,}"#,
        #"(?-i:\b(?:AKIA|ASIA)[A-Z0-9]{16}\b)"#,
        #"\bsk-[A-Za-z0-9_-]{20,}"#,
        #"\b[sr]k_(?:live|test)_[A-Za-z0-9]{16,}"#,
        // credential needs a digit, an inner capital or a base64 symbol, so prose like "Basic authentication" passes
        #"(?-i:\b(?:Bearer|Basic)[ \t]+(?=[A-Za-z0-9._~+/-]*(?:[0-9+/=]|[A-Za-z0-9][A-Z]))[A-Za-z0-9._~+/-]{8,}=*)"#
    ].map { pattern in
        do {
            return try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            fatalError("secret pattern does not compile: \(pattern)")
        }
    }

    static func matches(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return patterns.contains { $0.firstMatch(in: text, range: range) != nil }
    }
}
