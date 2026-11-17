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
    @State private var retention: RetentionSettings
    @State private var privacy: PrivacySettings

    init() {
        let repository = CardRepository(database: Self.openDatabase())
        let writer = PasteboardWriter()
        let privacy = PrivacySettings()
        _privacy = State(initialValue: privacy)
        let monitor = PasteboardMonitor(
            isOwnWrite: { writer.isOwnWrite($0) },
            policy: { privacy.capturePolicy },
            repository: repository
        )
        _ = Task {
            try await monitor.run()
        }
        let retention = RetentionSettings(repository: repository)
        _ = Task {
            try await retention.runPurgeSchedule()
        }
        _retention = State(initialValue: retention)

        let shelf = ShelfController(
            model: ShelfModel { repository.observeCards(in: $0) },
            paster: PasteCoordinator(writer: writer) { try await repository.representations(of: $0) },
            deletion: CardDeletion(
                delete: { try await repository.delete(cards: $0, in: $1) },
                restore: { try await repository.restore($0) }
            ),
            representations: { try await repository.representations(of: $0) },
            rename: { try await repository.rename(card: $0, to: $1) }
        )
        _shelf = State(initialValue: shelf)
        _ = Task {
            for await isShown in Observations({ privacy.showsShelfInScreenCapture }) {
                shelf.isShownInScreenCapture = isShown
            }
        }
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
                .environment(retention)
                .environment(privacy)
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
