import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts
import Observation

@MainActor
@Observable
public final class ShortcutSettings {
    public struct Recorder: Identifiable {
        public let name: KeyboardShortcuts.Name
        public let title: String

        public var id: String {
            name.rawValue
        }

        public init(name: KeyboardShortcuts.Name, title: String) {
            self.name = name
            self.title = title
        }
    }

    public enum Notice: Equatable {
        case conflict(shortcut: KeyboardShortcuts.Shortcut, usedBy: String)
        case optionOnly
    }

    public static var standardRecorders: [Recorder] {
        [
            Recorder(name: .toggleShelf, title: String(
                localized: "Open Shelf",
                comment: "Shortcut recorder label in the Shortcuts settings pane"
            )),
            Recorder(name: .previousBoard, title: String(
                localized: "Previous Board",
                comment: "Shortcut recorder label in the Shortcuts settings pane"
            )),
            Recorder(name: .nextBoard, title: String(
                localized: "Next Board",
                comment: "Shortcut recorder label in the Shortcuts settings pane"
            ))
        ]
    }

    public let recorders: [Recorder]
    public private(set) var modifiers: QuickPasteModifiers
    private var shortcuts: [String: KeyboardShortcuts.Shortcut] = [:]
    private var conflicts: [String: Notice] = [:]

    @ObservationIgnored private let store: any ShortcutStoring
    @ObservationIgnored private let defaults: UserDefaults

    public init(
        recorders: [Recorder] = ShortcutSettings.standardRecorders,
        store: any ShortcutStoring,
        defaults: UserDefaults = .standard
    ) {
        self.recorders = recorders
        self.store = store
        self.defaults = defaults
        modifiers = QuickPasteModifiers(defaults: defaults)
        reloadShortcuts()
    }

    public func shortcut(for name: KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut? {
        shortcuts[name.rawValue]
    }

    public func notice(for name: KeyboardShortcuts.Name) -> Notice? {
        if let conflict = conflicts[name.rawValue] {
            return conflict
        }
        guard let shortcut = shortcuts[name.rawValue],
              shortcut.modifiers.intersection([.command, .control, .option]) == .option
        else { return nil }
        return .optionOnly
    }

    /// the recorder has already stored the new shortcut, so a conflicting one is put back here
    public func recorderDidChange(_ name: KeyboardShortcuts.Name, to shortcut: KeyboardShortcuts.Shortcut?) {
        if let shortcut, let owner = owner(of: shortcut, except: name) {
            conflicts[name.rawValue] = .conflict(shortcut: shortcut, usedBy: owner)
            store.setShortcut(shortcuts[name.rawValue], for: name)
        } else {
            conflicts[name.rawValue] = nil
            store.setShortcut(shortcut, for: name)
        }
        shortcuts[name.rawValue] = store.shortcut(for: name)
        dropStaleConflicts()
    }

    public func isAvailable(quickPaste key: QuickPasteModifiers.Key) -> Bool {
        QuickPasteModifiers.quickPasteChoices.contains(key) && key != modifiers.plainText
    }

    public func isAvailable(plainText key: QuickPasteModifiers.Key) -> Bool {
        key != modifiers.quickPaste
    }

    public func setQuickPasteModifier(_ key: QuickPasteModifiers.Key) {
        guard isAvailable(quickPaste: key) else { return }
        defaults.set(key.rawValue, forKey: QuickPasteModifiers.quickPasteKey)
        modifiers = QuickPasteModifiers(defaults: defaults)
        dropStaleConflicts()
    }

    public func setPlainTextModifier(_ key: QuickPasteModifiers.Key) {
        guard isAvailable(plainText: key) else { return }
        defaults.set(key.rawValue, forKey: QuickPasteModifiers.plainTextKey)
        modifiers = QuickPasteModifiers(defaults: defaults)
        dropStaleConflicts()
    }

    public func restoreDefaults() {
        store.reset(recorders.map(\.name))
        defaults.removeObject(forKey: QuickPasteModifiers.quickPasteKey)
        defaults.removeObject(forKey: QuickPasteModifiers.plainTextKey)
        modifiers = QuickPasteModifiers(defaults: defaults)
        conflicts = [:]
        reloadShortcuts()
    }

    private func dropStaleConflicts() {
        conflicts = conflicts.filter { key, notice in
            guard case let .conflict(shortcut, usedBy) = notice,
                  let recorder = recorders.first(where: { $0.name.rawValue == key })
            else { return false }
            return owner(of: shortcut, except: recorder.name) == usedBy
        }
    }

    private func reloadShortcuts() {
        shortcuts = Dictionary(uniqueKeysWithValues: recorders.compactMap { recorder in
            store.shortcut(for: recorder.name).map { (recorder.name.rawValue, $0) }
        })
    }

    private func owner(of shortcut: KeyboardShortcuts.Shortcut, except name: KeyboardShortcuts.Name) -> String? {
        if let recorder = recorders.first(where: { $0.name != name && shortcuts[$0.name.rawValue] == shortcut }) {
            return recorder.title
        }
        return shelfShortcuts.first { $0.shortcut == shortcut }?.title
    }

    private var shelfShortcuts: [(shortcut: KeyboardShortcuts.Shortcut, title: String)] {
        let quickPaste = modifiers.quickPaste.flags
        let plainText = modifiers.plainText.flags
        let digits = [
            kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
            kVK_ANSI_Keypad1, kVK_ANSI_Keypad2, kVK_ANSI_Keypad3, kVK_ANSI_Keypad4, kVK_ANSI_Keypad5,
            kVK_ANSI_Keypad6, kVK_ANSI_Keypad7, kVK_ANSI_Keypad8, kVK_ANSI_Keypad9
        ]
        let quickPasteTitle = String(
            localized: "Quick Paste",
            comment: "Name of the Quick Paste shortcuts in a conflict message"
        )
        let quickPasteShortcuts = digits.flatMap { code in
            [quickPaste, quickPaste.union(plainText)].map { flags in
                (KeyboardShortcuts.Shortcut(KeyboardShortcuts.Key(rawValue: code), modifiers: flags), quickPasteTitle)
            }
        }
        let plainTextPasteTitle = String(
            localized: "Paste as Plain Text",
            comment: "Name of a shelf shortcut in a conflict message"
        )
        return [
            (.init(.return, modifiers: plainText), plainTextPasteTitle),
            (.init(.keypadEnter, modifiers: plainText), plainTextPasteTitle),
            (
                .init(.upArrow, modifiers: .command),
                String(localized: "First Card", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.downArrow, modifiers: .command),
                String(localized: "Last Card", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.a, modifiers: .command),
                String(localized: "Select All", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.c, modifiers: .command),
                String(localized: "Copy", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.c, modifiers: plainText.union(.command)),
                String(localized: "Copy as Plain Text", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.o, modifiers: .command),
                String(localized: "Open", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.z, modifiers: .command),
                String(localized: "Undo", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.f, modifiers: .command),
                String(localized: "Search", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.n, modifiers: [.command, .shift]),
                String(localized: "New Board", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.t, modifiers: .command),
                String(localized: "Pause Capture", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.n, modifiers: .command),
                String(localized: "New Text Card", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.r, modifiers: .command),
                String(localized: "Rename", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.e, modifiers: .command),
                String(localized: "Edit", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.g, modifiers: .command),
                String(localized: "Show in List", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.comma, modifiers: .command),
                String(localized: "Settings…", comment: "Name of a shelf shortcut in a conflict message")
            ),
            (
                .init(.q, modifiers: .command),
                String(localized: "Quit Clipsy", comment: "Name of a shelf shortcut in a conflict message")
            )
        ] + quickPasteShortcuts
    }
}
