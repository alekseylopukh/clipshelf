import Foundation

public struct HexColor: Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Parses copied text as a color using the hex rule in docs/product.md §4.2.
    public init?(copiedText: String) {
        let trimmed = copiedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasHash = trimmed.hasPrefix("#")
        let digits = hasHash ? trimmed.dropFirst() : Substring(trimmed)
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit) else { return nil }
        guard hasHash || digits.contains(where: \.isLetter) else { return nil }
        guard let value = UInt32(digits, radix: 16) else { return nil }
        self.init(red: UInt8(value >> 16 & 0xFF), green: UInt8(value >> 8 & 0xFF), blue: UInt8(value & 0xFF))
    }
}
