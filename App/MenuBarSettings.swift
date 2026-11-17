import Foundation
import Observation

@Observable
final class MenuBarSettings {
    private static let isItemShownKey = "ShowsMenuBarItem"
    private static let clickOpensShelfKey = "MenuBarClickOpensShelf"

    var isItemShown: Bool {
        didSet { defaults.set(isItemShown, forKey: Self.isItemShownKey) }
    }

    var clickOpensShelf: Bool {
        didSet { defaults.set(clickOpensShelf, forKey: Self.clickOpensShelfKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isItemShown = defaults.object(forKey: Self.isItemShownKey) as? Bool ?? true
        clickOpensShelf = defaults.bool(forKey: Self.clickOpensShelfKey)
    }
}
