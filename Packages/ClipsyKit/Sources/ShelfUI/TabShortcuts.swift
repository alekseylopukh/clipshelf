import AppKit
import KeyboardShortcuts

/// reads what the `.previousBoard` and `.nextBoard` recorders store; the names stay unregistered (WD-36)
public struct TabShortcuts: Equatable, Sendable {
    public static let previousKey = storageKey(for: .previousBoard)
    public static let nextKey = storageKey(for: .nextBoard)

    public let previous: KeyboardShortcuts.Shortcut?
    public let next: KeyboardShortcuts.Shortcut?

    public init(defaults: UserDefaults) {
        previous = Self.shortcut(for: .previousBoard, in: defaults)
        next = Self.shortcut(for: .nextBoard, in: defaults)
    }

    func direction(of shortcut: KeyboardShortcuts.Shortcut) -> ShelfModel.Direction? {
        switch shortcut {
        case previous: .previous
        case next: .next
        default: nil
        }
    }

    /// must match KeyboardShortcuts' own storage: a JSON string, or `false` when the recorder is cleared
    private static func storageKey(for name: KeyboardShortcuts.Name) -> String {
        "KeyboardShortcuts_\(name.rawValue)"
    }

    private static func shortcut(
        for name: KeyboardShortcuts.Name,
        in defaults: UserDefaults
    ) -> KeyboardShortcuts.Shortcut? {
        let key = storageKey(for: name)
        guard defaults.object(forKey: key) != nil else { return name.defaultShortcut }
        return defaults.string(forKey: key)?.data(using: .utf8)
            .flatMap { try? JSONDecoder().decode(KeyboardShortcuts.Shortcut.self, from: $0) }
    }
}
