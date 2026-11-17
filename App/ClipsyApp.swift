import SwiftUI

@main
struct ClipsyApp: App {
    var body: some Scene {
        MenuBarExtra("Clipsy", systemImage: "list.clipboard") {
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")
            Divider()
            Button("Quit Clipsy") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsView()
        }
    }
}
