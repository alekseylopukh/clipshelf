import CoreGraphics
import Foundation
import Store
import Testing
@testable import ShelfUI

@MainActor
struct ColorCardEditorTests {
    private final class Calls {
        var replaced: [String] = []
    }

    private let calls = Calls()

    private func editor(_ value: String) -> ColorCardEditor {
        let card = CardSummary(id: 1, kind: .color, metadata: #"{"color":"\#(value)"}"#, createdAt: .now)
        return ColorCardEditor(card: card) { [calls] representations in
            calls.replaced += representations.compactMap { String(bytes: $0.data, encoding: .utf8) }
        }
    }

    @Test(arguments: [("#1A2B3C", CardColor.Format.hex), ("rgb(26, 43, 60)", .rgb)])
    func `opens in the card's format`(value: String, format: CardColor.Format) {
        let editor = editor(value)

        #expect(editor.format == format)
        #expect(editor.color == CardColor(red: 26, green: 43, blue: 60))
        #expect(editor.value == value)
    }

    @Test func `format picker rewrites the value`() async {
        let editor = editor("#1A2B3C")

        editor.setFormat(.rgb)

        #expect(editor.value == "rgb(26, 43, 60)")
        #expect(await editor.save())
        #expect(calls.replaced == ["rgb(26, 43, 60)"])
    }

    @Test func `color panel pick is written in the chosen format`() throws {
        let editor = editor("rgb(0, 0, 0)")
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let picked = try #require(CGColor(colorSpace: space, components: [1, 0.5, 0, 1]))

        editor.setColor(picked)

        #expect(editor.value == "rgb(255, 128, 0)")
        #expect(editor.cgColor.components == [1, 128.0 / 255, 0, 1])
    }

    @Test func `wide gamut pick is clamped to sRGB`() throws {
        let editor = editor("#000000")
        let space = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let picked = try #require(CGColor(colorSpace: space, components: [1, 0, 0, 1]))

        editor.setColor(picked)

        #expect(editor.value == "#FF0000")
    }

    @Test func `typed value sets color and format`() async {
        let editor = editor("#000000")

        editor.setValue("rgb(1, 2")
        #expect(editor.canSave == false)
        #expect(await editor.save() == false)

        editor.setValue("aabbcc")
        #expect(editor.format == .hex)
        #expect(editor.color == CardColor(red: 0xAA, green: 0xBB, blue: 0xCC))
        #expect(await editor.save())
        #expect(calls.replaced == ["#AABBCC"])
    }

    @Test func `saving without changes writes nothing`() async {
        #expect(await editor("1a2b3c").save())
        #expect(calls.replaced.isEmpty)
    }
}
