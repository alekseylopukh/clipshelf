import AppKit
import Capture
import DesignSystem
import ShelfUI
import Store
import SwiftUI
import Testing
import Updates

/// renders the Settings panes and the onboarding steps offscreen; run with scripts/snapshots.sh
@MainActor
@Suite(.enabled(if: snapshotDirectory != nil), .serialized)
final class AppSnapshotTests {
    private let suiteName = "AppSnapshotTests-\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let retention: RetentionSettings
    private let access: PasteboardAccess

    init() throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("a unique suite name always opens a defaults domain")
        }
        self.defaults = defaults
        retention = try RetentionSettings(
            repository: CardRepository(database: AppDatabase.temporary()),
            defaults: defaults
        )
        access = PasteboardAccess(pasteboard: AskingPasteboard(), defaults: defaults)
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test(arguments: SnapshotRenderer.Appearance.allCases, SettingsPane.allCases)
    func `render a settings pane`(appearance: SnapshotRenderer.Appearance, pane: SettingsPane) async throws {
        let root = Group {
            switch pane {
            case .general: GeneralSettingsView()
            case .shortcuts: ShortcutsSettingsView()
            case .privacy: PrivacySettingsView()
            case .about: AboutSettingsView()
            }
        }
        .frame(width: DesignTokens.settingsWidth)
        .environment(retention)
        .environment(PrivacySettings(defaults: defaults))
        .environment(access)
        .environment(MenuBarSettings(defaults: defaults))
        .environment(ShortcutSettings(store: KeyboardShortcutsStore(), defaults: defaults))
        .environment(AppUpdater(driver: StaticUpdaterDriver()))
        .background(.windowBackground)
        try await SnapshotRenderer.render(root, named: "settings-\(pane.rawValue)", appearance: appearance)
    }

    @Test(arguments: SnapshotRenderer.Appearance.allCases)
    func `render the onboarding steps`(appearance: SnapshotRenderer.Appearance) async throws {
        let flow = OnboardingFlow(access: access, defaults: defaults)
        for step in ["welcome", "paste-directly", "clipboard-access", "finish"] {
            let root = OnboardingView()
                .environment(flow)
                .environment(access)
                .environment(retention)
                .background(.windowBackground)
            try await SnapshotRenderer.render(root, named: "onboarding-\(step)", appearance: appearance)
            flow.advance()
        }
    }
}

extension SettingsPane: CaseIterable {
    static let allCases: [SettingsPane] = [.general, .shortcuts, .privacy, .about]
}

/// reports that macOS asks before Clipsy reads the clipboard, so the onboarding shows its clipboard step
private struct AskingPasteboard: PasteboardAccessReading {
    let accessBehavior = NSPasteboard.AccessBehavior.ask
}

private final class StaticUpdaterDriver: UpdaterDriver {
    var automaticallyChecksForUpdates = false

    func start() {}

    func checkForUpdates() {}
}
