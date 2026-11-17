import Store
import SwiftUI

struct SettingsView: View {
    @AppStorage("SettingsPane") private var pane = SettingsPane.general

    var body: some View {
        TabView(selection: $pane) {
            Tab("General", systemImage: "gearshape", value: SettingsPane.general) {
                GeneralSettingsView()
            }
        }
        .frame(width: 500)
    }
}

enum SettingsPane: String {
    case general
}

#Preview {
    if let database = try? AppDatabase.temporary() {
        SettingsView()
            .environment(RetentionSettings(repository: CardRepository(database: database)))
    }
}
