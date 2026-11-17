import AppKit
import Carbon.HIToolbox
import Foundation
import KeyboardShortcuts
import Testing
@testable import ShelfUI

@MainActor
final class ShortcutSettingsTests {
    private let suiteName = "ShortcutSettingsTests-\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let store = FakeShortcutStore()
    private let open = KeyboardShortcuts.Name("test-open")
    private let next = KeyboardShortcuts.Name("test-next")

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        store.defaults = [
            open.rawValue: .init(.v, modifiers: [.command, .shift]),
            next.rawValue: .init(.rightArrow, modifiers: .command)
        ]
        store.reset([open, next])
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makeSettings() -> ShortcutSettings {
        ShortcutSettings(
            recorders: [.init(name: open, title: "Open"), .init(name: next, title: "Next")],
            store: store,
            defaults: defaults
        )
    }

    @Test func `modifiers must differ`() {
        let settings = makeSettings()

        settings.setPlainTextModifier(.command)
        #expect(settings.modifiers == QuickPasteModifiers(quickPaste: .command, plainText: .shift))
        #expect(settings.isAvailable(plainText: .command) == false)

        settings.setPlainTextModifier(.option)
        settings.setQuickPasteModifier(.option)
        #expect(settings.modifiers == QuickPasteModifiers(quickPaste: .command, plainText: .option))
        #expect(settings.isAvailable(quickPaste: .option) == false)

        settings.setQuickPasteModifier(.control)
        #expect(QuickPasteModifiers(defaults: defaults) == QuickPasteModifiers(
            quickPaste: .control,
            plainText: .option
        ))
    }

    @Test func `shift can never be the Quick Paste modifier`() {
        let settings = makeSettings()
        settings.setPlainTextModifier(.option)

        settings.setQuickPasteModifier(.shift)

        #expect(settings.modifiers.quickPaste == .command)
    }

    @Test func `restore defaults resets all`() {
        let settings = makeSettings()
        settings.setQuickPasteModifier(.control)
        settings.setPlainTextModifier(.option)
        settings.recorderDidChange(open, to: nil)
        store.setShortcut(.init(.n, modifiers: [.command, .option]), for: next)
        settings.recorderDidChange(next, to: .init(.n, modifiers: [.command, .option]))
        store.setShortcut(.init(.c, modifiers: .command), for: next)
        settings.recorderDidChange(next, to: .init(.c, modifiers: .command))

        settings.restoreDefaults()

        #expect(settings.modifiers == QuickPasteModifiers())
        #expect(defaults.object(forKey: QuickPasteModifiers.quickPasteKey) == nil)
        #expect(defaults.object(forKey: QuickPasteModifiers.plainTextKey) == nil)
        #expect(settings.shortcut(for: open) == .init(.v, modifiers: [.command, .shift]))
        #expect(settings.shortcut(for: next) == .init(.rightArrow, modifiers: .command))
        #expect(settings.notice(for: next) == nil)
    }

    @Test func `recorder rejects a shortcut another Clipsy shortcut uses`() {
        let settings = makeSettings()
        let taken = KeyboardShortcuts.Shortcut(.v, modifiers: [.command, .shift])
        store.setShortcut(taken, for: next)

        settings.recorderDidChange(next, to: taken)

        #expect(store.shortcut(for: next) == .init(.rightArrow, modifiers: .command))
        #expect(settings.shortcut(for: next) == .init(.rightArrow, modifiers: .command))
        #expect(settings.notice(for: next) == .conflict(shortcut: taken, usedBy: "Open"))
    }

    @Test func `start sequence may take the copy as plain text combination`() {
        let settings = ShortcutSettings(
            recorders: [.init(name: .startSequence, title: "Start Sequence"), .init(name: next, title: "Next")],
            store: store,
            defaults: defaults
        )
        let copyAsPlainText = KeyboardShortcuts.Shortcut(.c, modifiers: [.command, .shift])

        store.setShortcut(copyAsPlainText, for: .startSequence)
        settings.recorderDidChange(.startSequence, to: copyAsPlainText)
        store.setShortcut(copyAsPlainText, for: next)
        settings.recorderDidChange(next, to: copyAsPlainText)

        #expect(settings.shortcut(for: .startSequence) == copyAsPlainText)
        #expect(settings.notice(for: .startSequence) == nil)
        #expect(settings.notice(for: next) == .conflict(shortcut: copyAsPlainText, usedBy: "Start Sequence"))
    }

    @Test func `conflict notice clears when its owner moves`() {
        let settings = makeSettings()
        let taken = KeyboardShortcuts.Shortcut(.v, modifiers: [.command, .shift])
        store.setShortcut(taken, for: next)
        settings.recorderDidChange(next, to: taken)

        let moved = KeyboardShortcuts.Shortcut(.b, modifiers: [.command, .shift])
        store.setShortcut(moved, for: open)
        settings.recorderDidChange(open, to: moved)

        #expect(settings.notice(for: next) == nil)
    }

    @Test(arguments: [
        KeyCase(keyCode: kVK_ANSI_C, flags: .command),
        KeyCase(keyCode: kVK_ANSI_C, flags: [.command, .shift]),
        KeyCase(keyCode: kVK_ANSI_4, flags: .command),
        KeyCase(keyCode: kVK_ANSI_Q, flags: .command),
        KeyCase(keyCode: kVK_ANSI_Keypad4, flags: [.command, .shift])
    ])
    func `recorder rejects shortcuts the shelf uses`(keyCase: KeyCase) {
        let settings = makeSettings()
        let shortcut = KeyboardShortcuts.Shortcut(
            KeyboardShortcuts.Key(rawValue: keyCase.keyCode),
            modifiers: keyCase.flags
        )
        store.setShortcut(shortcut, for: next)

        settings.recorderDidChange(next, to: shortcut)

        #expect(store.shortcut(for: next) == .init(.rightArrow, modifiers: .command))
        guard case .conflict = settings.notice(for: next) else {
            Issue.record("expected a conflict")
            return
        }
    }

    @Test(arguments: [kVK_Return, kVK_ANSI_KeypadEnter])
    func `recorder rejects the plain text paste key`(keyCode: Int) {
        let settings = makeSettings()
        settings.setPlainTextModifier(.control)
        let shortcut = KeyboardShortcuts.Shortcut(KeyboardShortcuts.Key(rawValue: keyCode), modifiers: .control)
        store.setShortcut(shortcut, for: next)

        settings.recorderDidChange(next, to: shortcut)

        #expect(store.shortcut(for: next) == .init(.rightArrow, modifiers: .command))
        #expect(settings.notice(for: next) == .conflict(shortcut: shortcut, usedBy: "Paste as Plain Text"))
    }

    @Test func `cleared shortcut stays cleared and clears the conflict`() {
        let settings = makeSettings()
        settings.recorderDidChange(next, to: .init(.c, modifiers: .command))

        store.setShortcut(nil, for: next)
        settings.recorderDidChange(next, to: nil)

        #expect(settings.shortcut(for: next) == nil)
        #expect(store.shortcut(for: next) == nil)
        #expect(settings.notice(for: next) == nil)
    }

    @Test(arguments: [
        FlagsCase(flags: .option, expected: true),
        FlagsCase(flags: [.option, .shift], expected: true),
        FlagsCase(flags: [.option, .command], expected: false),
        FlagsCase(flags: .control, expected: false)
    ])
    func `option-only shortcuts get a warning`(flagsCase: FlagsCase) {
        let settings = makeSettings()
        let shortcut = KeyboardShortcuts.Shortcut(.k, modifiers: flagsCase.flags)
        store.setShortcut(shortcut, for: next)

        settings.recorderDidChange(next, to: shortcut)

        #expect((settings.notice(for: next) == .optionOnly) == flagsCase.expected)
    }

    @Test(arguments: [
        KeyCase(keyCode: kVK_Return, flags: [], expected: .paste),
        KeyCase(keyCode: kVK_ANSI_KeypadEnter, flags: .option, expected: .pasteAsPlainText),
        KeyCase(keyCode: kVK_Return, flags: [.option, .capsLock], expected: .pasteAsPlainText),
        KeyCase(keyCode: kVK_Return, flags: .shift, expected: nil),
        KeyCase(keyCode: kVK_Return, flags: [.option, .command], expected: nil),
        KeyCase(keyCode: kVK_ANSI_C, flags: .command, expected: .copy),
        KeyCase(keyCode: kVK_ANSI_C, flags: [.command, .option], expected: .copyAsPlainText),
        KeyCase(keyCode: kVK_ANSI_C, flags: [.command, .shift], expected: nil),
        KeyCase(keyCode: kVK_ANSI_C, flags: .option, expected: nil),
        KeyCase(
            keyCode: kVK_ANSI_C,
            flags: .command,
            expected: .copy,
            modifiers: QuickPasteModifiers(quickPaste: .option, plainText: .command)
        ),
        KeyCase(
            keyCode: kVK_Return,
            flags: .command,
            expected: .pasteAsPlainText,
            modifiers: QuickPasteModifiers(quickPaste: .option, plainText: .command)
        )
    ])
    func `return and copy honor the plain-text modifier`(keyCase: KeyCase) {
        let modifiers = keyCase.modifiers
        let character = keyCase.keyCode == kVK_ANSI_C ? "c" : "\r"

        let command = modifiers.command(
            keyCode: UInt16(keyCase.keyCode),
            character: character,
            modifierFlags: keyCase.flags
        )

        #expect(command == keyCase.expected)
    }

    @Test func `double-click honors the plain-text modifier`() {
        let modifiers = QuickPasteModifiers(quickPaste: .command, plainText: .control)

        #expect(modifiers.doubleClickCommand(modifierFlags: []) == .paste)
        #expect(modifiers.doubleClickCommand(modifierFlags: .shift) == .paste)
        #expect(modifiers.doubleClickCommand(modifierFlags: .control) == .pasteAsPlainText)
    }

    struct KeyCase: Sendable, CustomTestStringConvertible {
        let keyCode: Int
        let flags: NSEvent.ModifierFlags
        var expected: CardCommand?
        var modifiers = QuickPasteModifiers(quickPaste: .command, plainText: .option)

        var testDescription: String {
            "key \(keyCode), flags \(flags.rawValue), plain text \(modifiers.plainText)"
        }
    }

    struct FlagsCase: Sendable, CustomTestStringConvertible {
        let flags: NSEvent.ModifierFlags
        let expected: Bool

        var testDescription: String {
            "flags \(flags.rawValue)"
        }
    }
}

@MainActor
private final class FakeShortcutStore: ShortcutStoring {
    var defaults: [String: KeyboardShortcuts.Shortcut] = [:]
    private var shortcuts: [String: KeyboardShortcuts.Shortcut] = [:]

    func shortcut(for name: KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut? {
        shortcuts[name.rawValue]
    }

    func setShortcut(_ shortcut: KeyboardShortcuts.Shortcut?, for name: KeyboardShortcuts.Name) {
        shortcuts[name.rawValue] = shortcut
    }

    func reset(_ names: [KeyboardShortcuts.Name]) {
        for name in names {
            shortcuts[name.rawValue] = defaults[name.rawValue]
        }
    }
}
