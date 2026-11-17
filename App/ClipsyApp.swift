import ShelfUI
import SwiftUI

@main
struct ClipsyApp: App {
    @State private var shelf: ShelfController

    init() {
        let shelf = ShelfController()
        _shelf = State(initialValue: shelf)
        KeyboardShortcuts.onKeyUp(for: .toggleShelf) {
            shelf.toggle()
        }
    }

    var body: some Scene {
        MenuBarExtra("Clipsy", systemImage: "list.clipboard") {
            Button("Open Shelf") {
                shelf.show()
            }
            Divider()
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
