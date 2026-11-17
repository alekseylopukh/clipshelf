import KeyboardShortcuts

@MainActor
public protocol ShortcutStoring {
    func shortcut(for name: KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?
    func setShortcut(_ shortcut: KeyboardShortcuts.Shortcut?, for name: KeyboardShortcuts.Name)
    func reset(_ names: [KeyboardShortcuts.Name])
}

/// KeyboardShortcuts registers a global hotkey on every write and unregisters an old one by value, whoever owns it
@MainActor
public struct KeyboardShortcutsStore: ShortcutStoring {
    public init() {
        Self.syncRegistrations()
    }

    public func shortcut(for name: KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: name)
    }

    public func setShortcut(_ shortcut: KeyboardShortcuts.Shortcut?, for name: KeyboardShortcuts.Name) {
        KeyboardShortcuts.setShortcut(shortcut, for: name)
        Self.syncRegistrations()
    }

    public func reset(_ names: [KeyboardShortcuts.Name]) {
        KeyboardShortcuts.reset(names)
        Self.syncRegistrations()
    }

    private static func syncRegistrations() {
        KeyboardShortcuts.disable(KeyboardShortcuts.Name.shelfOnly)
        KeyboardShortcuts.enable(KeyboardShortcuts.Name.global)
    }
}
