@_exported import KeyboardShortcuts

public extension KeyboardShortcuts.Name {
    static let toggleShelf = Self("toggleShelf", default: .init(.v, modifiers: [.command, .shift]))
    static let previousBoard = Self("previousBoard", default: .init(.leftArrow, modifiers: .command))
    static let nextBoard = Self("nextBoard", default: .init(.rightArrow, modifiers: .command))

    /// handled inside the shelf; they must never stay registered as global hotkeys
    static let shelfOnly: [Self] = [.previousBoard, .nextBoard]
}
