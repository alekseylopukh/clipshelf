import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            LabeledContent("Version", value: Bundle.main.marketingVersion)
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}

private extension Bundle {
    var marketingVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

#Preview {
    SettingsView()
}
