import AppKit
import Capture
import os
import Pasting
import ShelfUI
import Store
import SwiftUI

@main
struct ClipsyApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var shelf: ShelfController
    @State private var retention: RetentionSettings
    @State private var privacy: PrivacySettings
    @State private var menuBarSettings: MenuBarSettings
    @State private var statusItem: StatusItemController

    init() {
        let repository = CardRepository(database: Self.openDatabase())
        let writer = PasteboardWriter()
        let privacy = PrivacySettings()
        _privacy = State(initialValue: privacy)
        let pause = CapturePause()
        let monitor = PasteboardMonitor(
            isOwnWrite: { writer.isOwnWrite($0) },
            policy: { Self.capturePolicy(privacy: privacy, pause: pause) },
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
            rename: { try await repository.rename(card: $0, to: $1) },
            togglePause: { pause.isPaused.toggle() }
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

        let menuBarSettings = MenuBarSettings()
        _menuBarSettings = State(initialValue: menuBarSettings)
        let statusItem = StatusItemController(pause: pause, settings: menuBarSettings) {
            shelf.show()
        }
        _statusItem = State(initialValue: statusItem)
        _ = Task {
            await statusItem.run()
        }
        let sounds = SoundEffects()
        _ = Task {
            for await _ in monitor.capturedCardIDs {
                sounds.play(.capture)
                statusItem.bounce()
            }
        }
        appDelegate.onReopen = {
            if !menuBarSettings.isItemShown {
                SettingsWindow.open()
            }
        }
    }

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(retention)
                .environment(privacy)
                .environment(menuBarSettings)
        }
    }

    private static func capturePolicy(privacy: PrivacySettings, pause: CapturePause) -> CapturePolicy {
        var policy = privacy.capturePolicy
        policy.isPaused = pause.isPaused
        return policy
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
