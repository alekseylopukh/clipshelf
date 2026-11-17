import AppKit
import Capture
import os
import Pasting
import ShelfUI
import Store
import SwiftUI

@main
struct ClipsyApp: App {
    @State private var shelf: ShelfController

    init() {
        let repository = CardRepository(database: Self.openDatabase())
        let writer = PasteboardWriter()
        let monitor = PasteboardMonitor(
            isOwnWrite: { writer.isOwnWrite($0) },
            policy: { CapturePolicy() },
            repository: repository
        )
        _ = Task {
            try await monitor.run()
        }

        let shelf = ShelfController(
            model: ShelfModel { repository.observeCards(in: $0) },
            paster: PasteCoordinator(writer: writer) { try await repository.representations(of: $0) }
        )
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
        let logger = Logger(subsystem: "app.gonar.clipsy", category: "Startup")
        do {
            let opened = try AppDatabase.openRecoveringDamagedStore(directory: AppDatabase.defaultDirectory)
            if let backup = opened.backupDirectory {
                logger.error("the database was damaged and was moved aside")
                showRecoveryAlert(backup: backup)
            }
            return opened.database
        } catch {
            logger.fault("opening the database failed: \(String(describing: type(of: error)), privacy: .public)")
            let alert = NSAlert(error: error)
            alert.messageText = String(localized: "Clipsy can’t open its clipboard history.")
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: String(localized: "Quit Clipsy"))
            NSApplication.shared.activate()
            alert.runModal()
            exit(EXIT_FAILURE)
        }
    }

    private static func showRecoveryAlert(backup: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Clipsy’s clipboard history was damaged.")
        alert.informativeText = String(
            localized: "Clipsy moved it to “\(backup.path(percentEncoded: false))” and started a new, empty history."
        )
        alert.addButton(withTitle: String(localized: "OK"))
        alert.addButton(withTitle: String(localized: "Show in Finder"))
        NSApplication.shared.activate()
        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([backup])
        }
    }
}
