import AppKit
import Capture
import os
import ShelfUI
import Store
import SwiftUI

@main
struct ClipsyApp: App {
    @State private var shelf: ShelfController

    init() {
        let database = Self.openDatabase()
        let monitor = PasteboardMonitor(
            isOwnWrite: { _ in false },
            policy: { CapturePolicy() },
            repository: CardRepository(database: database)
        )
        _ = Task {
            try await monitor.run()
        }

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

    /// migrations must finish before any UI shows (architecture §3.4), so this runs synchronously at launch
    private static func openDatabase() -> AppDatabase {
        do {
            return try AppDatabase(directory: AppDatabase.defaultDirectory)
        } catch {
            Logger(subsystem: "app.gonar.clipsy", category: "Startup")
                .fault("opening the database failed: \(String(describing: type(of: error)), privacy: .public)")
            let alert = NSAlert(error: error)
            alert.messageText = String(localized: "Clipsy can’t open its clipboard history.")
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: String(localized: "Quit Clipsy"))
            NSApplication.shared.activate()
            alert.runModal()
            exit(EXIT_FAILURE)
        }
    }
}
