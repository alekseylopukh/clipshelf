import Capture
import ShelfUI
import Store
import SwiftUI

struct SettingsView: View {
    @AppStorage("SettingsPane") private var pane = SettingsPane.general

    var body: some View {
        TabView(selection: $pane) {
            Tab("General", systemImage: "gearshape", value: SettingsPane.general) {
                GeneralSettingsView()
            }
            Tab("Shortcuts", systemImage: "command", value: SettingsPane.shortcuts) {
                ShortcutsSettingsView()
            }
            Tab("Privacy", systemImage: "hand.raised", value: SettingsPane.privacy) {
                PrivacySettingsView()
            }
        }
        .frame(width: 500)
    }
}

enum SettingsPane: String {
    case general
    case shortcuts
    case privacy
}

#Preview {
    if let database = try? AppDatabase.temporary() {
        SettingsView()
            .environment(RetentionSettings(repository: CardRepository(database: database)))
            .environment(PrivacySettings())
            .environment(MenuBarSettings())
            .environment(ShortcutSettings(store: KeyboardShortcutsStore()))
    }
}
