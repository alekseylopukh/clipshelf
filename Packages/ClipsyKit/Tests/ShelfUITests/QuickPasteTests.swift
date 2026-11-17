import AppKit
import Carbon.HIToolbox
import Foundation
import Store
import Testing
@testable import ShelfUI

@MainActor
final class QuickPasteTests {
    private let suiteName = "QuickPasteTests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makeModel(cards ids: [Int64]) -> ShelfModel {
        let model = ShelfModel(defaults: defaults) { _ in AsyncThrowingStream { $0.finish() } }
        model.receive(ids.map { CardSummary(
            id: $0,
            kind: .text,
            createdAt: Date(timeIntervalSince1970: TimeInterval($0))
        ) })
        return model
    }

    @Test func `badges count from first visible card`() {
        let model = makeModel(cards: Array((1 ... 20).reversed()))
        model.setVisibleCards([8, 15, 10, 12, 11, 9, 14, 13])
        model.setQuickPasteModifierHeld(true)

        #expect(model.quickPasteNumber(for: 15) == 1)
        #expect(model.quickPasteNumber(for: 12) == 4)
        #expect(model.quickPasteNumber(for: 8) == 8)
        #expect(model.quickPasteNumber(for: 16) == nil)
        #expect(model.quickPasteCard(number: 3) == 13)

        model.setVisibleCards(Array(1 ... 12))
        #expect(model.quickPasteNumber(for: 12) == 1)
        #expect(model.quickPasteNumber(for: 4) == 9)
        #expect(model.quickPasteNumber(for: 3) == nil)
    }

    @Test func `badges show only while the modifier is held`() {
        let model = makeModel(cards: [3, 2, 1])
        model.setVisibleCards([3, 2, 1])

        #expect(model.quickPasteNumber(for: 3) == nil)
        model.setQuickPasteModifierHeld(true)
        #expect(model.quickPasteNumber(for: 3) == 1)
        model.setQuickPasteModifierHeld(false)
        #expect(model.quickPasteNumber(for: 3) == nil)
        #expect(model.quickPasteCard(number: 1) == 3)
    }

    @Test(arguments: [0, 4, 9, 10])
    func `digit beyond visible count does nothing`(number: Int) {
        let model = makeModel(cards: [6, 5, 4, 3, 2, 1])
        model.setVisibleCards([6, 5, 4])

        #expect(model.quickPasteCard(number: number) == nil)
    }

    @Test func `deleted and new cards renumber`() {
        let model = makeModel(cards: [3, 2, 1])
        model.setVisibleCards([3, 2, 1])

        model.receive([4, 2, 1].map { CardSummary(
            id: $0,
            kind: .text,
            createdAt: Date(timeIntervalSince1970: TimeInterval($0))
        ) })
        #expect(model.quickPasteCard(number: 1) == 2)
        #expect(model.quickPasteCard(number: 2) == 1)
    }

    @Test func `switching tabs clears visible cards`() {
        let model = makeModel(cards: [3, 2, 1])
        model.setVisibleCards([3, 2, 1])

        model.showTab(.board(id: 7))
        model.receive([3, 2, 1].map { CardSummary(
            id: $0,
            kind: .text,
            createdAt: Date(timeIntervalSince1970: TimeInterval($0))
        ) })
        #expect(model.quickPasteCard(number: 1) == nil)
    }

    struct ShortcutCase: Sendable, CustomTestStringConvertible {
        let keyCode: Int
        let flags: NSEvent.ModifierFlags
        let expected: Expected?

        struct Expected: Equatable {
            let number: Int
            let plainText: Bool
        }

        var testDescription: String {
            "key \(keyCode), flags \(flags.rawValue)"
        }
    }

    @Test(arguments: [
        ShortcutCase(keyCode: kVK_ANSI_3, flags: .command, expected: .init(number: 3, plainText: false)),
        ShortcutCase(keyCode: kVK_ANSI_3, flags: [.command, .shift], expected: .init(number: 3, plainText: true)),
        ShortcutCase(keyCode: kVK_ANSI_9, flags: [.command, .capsLock], expected: .init(number: 9, plainText: false)),
        ShortcutCase(
            keyCode: kVK_ANSI_Keypad1,
            flags: [.command, .numericPad],
            expected: .init(number: 1, plainText: false)
        ),
        ShortcutCase(keyCode: kVK_ANSI_3, flags: [], expected: nil),
        ShortcutCase(keyCode: kVK_ANSI_3, flags: .shift, expected: nil),
        ShortcutCase(keyCode: kVK_ANSI_3, flags: [.command, .option], expected: nil),
        ShortcutCase(keyCode: kVK_ANSI_0, flags: .command, expected: nil),
        ShortcutCase(keyCode: kVK_ANSI_C, flags: .command, expected: nil)
    ])
    func `default modifiers match command digit`(shortcut: ShortcutCase) {
        let match = QuickPasteModifiers().shortcut(keyCode: UInt16(shortcut.keyCode), modifierFlags: shortcut.flags)

        #expect(match.map { ShortcutCase.Expected(number: $0.number, plainText: $0.plainText) } == shortcut.expected)
    }

    @Test func `modifiers come from settings`() throws {
        defaults.set("control", forKey: QuickPasteModifiers.quickPasteKey)
        defaults.set("option", forKey: QuickPasteModifiers.plainTextKey)
        let modifiers = QuickPasteModifiers(defaults: defaults)

        let match = try #require(modifiers.shortcut(keyCode: UInt16(kVK_ANSI_2), modifierFlags: [.control, .option]))
        #expect(match.number == 2)
        #expect(match.plainText)
        #expect(modifiers.shortcut(keyCode: UInt16(kVK_ANSI_2), modifierFlags: .command) == nil)
        #expect(modifiers.isQuickPasteHeld(in: [.control, .shift]))
        #expect(modifiers.isQuickPasteHeld(in: .command) == false)
    }

    @Test(arguments: [
        ("shift", "shift", QuickPasteModifiers(quickPaste: .command, plainText: .shift)),
        ("option", "option", QuickPasteModifiers(quickPaste: .option, plainText: .shift)),
        ("bogus", "command", QuickPasteModifiers(quickPaste: .command, plainText: .shift)),
        ("option", "command", QuickPasteModifiers(quickPaste: .option, plainText: .command))
    ])
    func `invalid settings fall back to defaults`(
        quickPaste: String,
        plainText: String,
        expected: QuickPasteModifiers
    ) {
        defaults.set(quickPaste, forKey: QuickPasteModifiers.quickPasteKey)
        defaults.set(plainText, forKey: QuickPasteModifiers.plainTextKey)

        #expect(QuickPasteModifiers(defaults: defaults) == expected)
    }
}
