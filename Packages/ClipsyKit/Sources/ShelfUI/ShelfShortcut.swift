@_exported import KeyboardShortcuts

public extension KeyboardShortcuts.Name {
    static let toggleShelf = Self("toggleShelf", default: .init(.v, modifiers: [.command, .shift]))
    static let previousBoard = Self("previousBoard", default: .init(.leftArrow, modifiers: .command))
    static let nextBoard = Self("nextBoard", default: .init(.rightArrow, modifiers: .command))
    static let startSequence = Self("startSequence", default: .init(.c, modifiers: [.command, .shift]))
    static let pasteAllSequence = Self("pasteAllSequence", default: .init(.v, modifiers: [.command, .option, .control]))

    static let global: [Self] = [.toggleShelf, .startSequence, .pasteAllSequence]

    /// handled inside the shelf; they must never stay registered as global hotkeys
    static let shelfOnly: [Self] = [.previousBoard, .nextBoard]
}
