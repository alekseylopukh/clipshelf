import AppKit
import os

enum SettingsWindow {
    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Settings")

    /// swiftui offers `openSettings` only inside a scene, so this triggers the app menu item the Settings scene
    /// installs
    static func open() {
        NSApplication.shared.activate()
        guard let appMenu = NSApplication.shared.mainMenu?.items.first?.submenu,
              let index = appMenu.items.firstIndex(where: {
                  $0.keyEquivalent == "," && $0.keyEquivalentModifierMask == .command
              })
        else {
            logger.fault("the Settings menu item is missing")
            return
        }
        appMenu.performActionForItem(at: index)
    }
}
