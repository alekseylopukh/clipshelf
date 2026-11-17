import Foundation

public struct CardColor: Hashable, Sendable {
    public enum Format: CaseIterable, Sendable {
        case hex
        case rgb
    }

    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init?(copiedText: String) {
        guard let color = Self.parse(copiedText)?.color else { return nil }
        self = color
    }

    public static func format(of copiedText: String) -> Format? {
        parse(copiedText)?.format
    }

    public func text(in format: Format) -> String {
        switch format {
        case .hex:
            String(format: "#%02X%02X%02X", red, green, blue)
        case .rgb:
            "rgb(\(red), \(green), \(blue))"
        }
    }

    private static func parse(_ copiedText: String) -> (color: CardColor, format: Format)? {
        let trimmed = copiedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let color = hex(trimmed) {
            return (color, .hex)
        }
        if let color = rgb(trimmed) {
            return (color, .rgb)
        }
        return nil
    }

    private static func hex(_ text: String) -> CardColor? {
        let hasHash = text.hasPrefix("#")
        let digits = hasHash ? text.dropFirst() : Substring(text)
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit) else { return nil }
        guard hasHash || digits.contains(where: \.isLetter) else { return nil }
        guard let value = UInt32(digits, radix: 16) else { return nil }
        return CardColor(red: UInt8(value >> 16 & 0xFF), green: UInt8(value >> 8 & 0xFF), blue: UInt8(value & 0xFF))
    }

    private static func rgb(_ text: String) -> CardColor? {
        let lowercased = text.lowercased()
        guard lowercased.hasPrefix("rgb("), lowercased.hasSuffix(")") else { return nil }
        let components = lowercased.dropFirst(4).dropLast().split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count == 3 else { return nil }
        let values = components.compactMap { component -> UInt8? in
            guard (1 ... 3).contains(component.count), component.allSatisfy(\.isASCII), component.allSatisfy(\.isNumber)
            else { return nil }
            return UInt8(component)
        }
        guard values.count == 3 else { return nil }
        return CardColor(red: values[0], green: values[1], blue: values[2])
    }
}
