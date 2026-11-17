import AppKit
import Carbon.HIToolbox
import SwiftUI

public struct QuickPasteModifiers: Equatable, Sendable {
    public enum Key: String, Sendable, CaseIterable {
        case command
        case control
        case option
        case shift

        var flags: NSEvent.ModifierFlags {
            switch self {
            case .command: .command
            case .control: .control
            case .option: .option
            case .shift: .shift
            }
        }

        var eventModifiers: SwiftUI.EventModifiers {
            switch self {
            case .command: .command
            case .control: .control
            case .option: .option
            case .shift: .shift
            }
        }
    }

    public static let quickPasteKey = "QuickPasteModifier"
    public static let plainTextKey = "PlainTextModifier"
    public static let quickPasteChoices: [Key] = [.command, .option, .control]
    public static let plainTextChoices: [Key] = [.shift, .option, .control, .command]

    public let quickPaste: Key
    public let plainText: Key

    public init(quickPaste: Key = .command, plainText: Key = .shift) {
        self.quickPaste = quickPaste
        self.plainText = plainText
    }

    public init(defaults: UserDefaults) {
        let quickPaste = defaults.string(forKey: Self.quickPasteKey).flatMap(Key.init(rawValue:))
            .flatMap { Self.quickPasteChoices.contains($0) ? $0 : nil } ?? .command
        let plainText = defaults.string(forKey: Self.plainTextKey).flatMap(Key.init(rawValue:))
            .flatMap { $0 == quickPaste ? nil : $0 } ?? .shift
        self.init(quickPaste: quickPaste, plainText: plainText)
    }

    func isQuickPasteHeld(in modifierFlags: NSEvent.ModifierFlags) -> Bool {
        modifierFlags.contains(quickPaste.flags)
    }

    func command(keyCode: UInt16, character: String?, modifierFlags: NSEvent.ModifierFlags) -> CardCommand? {
        let modifiers = modifierFlags.intersection([.shift, .control, .option, .command])
        if [kVK_Return, kVK_ANSI_KeypadEnter].contains(Int(keyCode)) {
            if modifiers.isEmpty {
                return .paste
            }
            return modifiers == plainText.flags ? .pasteAsPlainText : nil
        }
        guard character == "c" else { return nil }
        if modifiers == .command {
            return .copy
        }
        return modifiers == plainText.flags.union(.command) ? .copyAsPlainText : nil
    }

    func doubleClickCommand(modifierFlags: NSEvent.ModifierFlags) -> CardCommand {
        modifierFlags.contains(plainText.flags) ? .pasteAsPlainText : .paste
    }

    func shortcut(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> (number: Int, plainText: Bool)? {
        guard let number = Self.digits[Int(keyCode)] else { return nil }
        let modifiers = modifierFlags.intersection([.shift, .control, .option, .command])
        guard modifiers.subtracting(plainText.flags) == quickPaste.flags else { return nil }
        return (number, modifiers.contains(plainText.flags))
    }

    private static let digits: [Int: Int] = [
        kVK_ANSI_1: 1, kVK_ANSI_2: 2, kVK_ANSI_3: 3, kVK_ANSI_4: 4, kVK_ANSI_5: 5,
        kVK_ANSI_6: 6, kVK_ANSI_7: 7, kVK_ANSI_8: 8, kVK_ANSI_9: 9,
        kVK_ANSI_Keypad1: 1, kVK_ANSI_Keypad2: 2, kVK_ANSI_Keypad3: 3, kVK_ANSI_Keypad4: 4, kVK_ANSI_Keypad5: 5,
        kVK_ANSI_Keypad6: 6, kVK_ANSI_Keypad7: 7, kVK_ANSI_Keypad8: 8, kVK_ANSI_Keypad9: 9
    ]
}
