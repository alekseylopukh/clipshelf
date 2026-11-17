import Foundation
import Store
import SwiftUI
import Testing
@testable import ShelfUI

struct CardContentTests {
    @Test func `color swatch is read from the copied hex value`() throws {
        let card = CardSummary(id: 1, kind: .color, metadata: ##"{"color":"#FF8000"}"##, createdAt: .now)
        let swatch = try #require(CardContent(card).swatch)
        #expect(swatch == Color(.sRGB, red: 1, green: 128.0 / 255, blue: 0))
    }

    @Test func `invalid color value has no swatch`() {
        let card = CardSummary(id: 1, kind: .color, metadata: ##"{"color":"orange"}"##, createdAt: .now)
        #expect(CardContent(card).swatch == nil)
    }

    @Test func `text value is the first line`() {
        let card = CardSummary(id: 1, kind: .text, preview: "First line\nSecond line", createdAt: .now)
        #expect(CardContent(card).accessibilityValue(of: card) == "First line")
    }

    @Test func `code-like flag applies only to text cards`() {
        let code = "let total = price * quantity"
        #expect(CardContent(CardSummary(id: 1, kind: .text, preview: code, createdAt: .now)).isCodeLike)
        #expect(CardContent(CardSummary(id: 2, kind: .link, preview: code, createdAt: .now)).isCodeLike == false)
    }
}
