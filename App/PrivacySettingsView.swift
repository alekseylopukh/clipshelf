import AppKit
import Capture
import DesignSystem
import SwiftUI
import UniformTypeIdentifiers

struct PrivacySettingsView: View {
    @Environment(PrivacySettings.self) private var privacy
    @Environment(PasteboardAccess.self) private var pasteboardAccess
    @Environment(\.appearsActive) private var appearsActive
    @State private var selection = Set<String>()
    @State private var isChoosingApps = false
    @State private var rejection: String?

    var body: some View {
        @Bindable var privacy = privacy
        Form {
            Section {
                Toggle("Ignore passwords and other concealed content", isOn: $privacy.ignoresConcealed)
                Toggle("Ignore temporary content from other apps", isOn: $privacy.ignoresTransient)
            }

            Section {
                List(selection: $selection) {
                    ForEach(privacy.ignoredBundleIDs, id: \.self) { bundleID in
                        IgnoredAppRow(bundleID: bundleID)
                    }
                }
                .listStyle(.bordered)
                .alternatingRowBackgrounds()
                .frame(height: DesignTokens.settingsListHeight)
                .onDeleteCommand(perform: removeSelectedApps)
                HStack(spacing: 0) {
                    Button("Add App…", systemImage: "plus") {
                        isChoosingApps = true
                    }
                    Button("Remove App", systemImage: "minus", action: removeSelectedApps)
                        .disabled(selection.isEmpty)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            } header: {
                Text("Ignored Apps")
            } footer: {
                Text(
                    "Clipsy doesn’t keep anything copied in these apps. Browser extensions of password managers may not mark copied passwords as concealed; to keep them out of your history, add your browser."
                )
                .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Show the Shelf in screenshots and screen sharing", isOn: $privacy.showsShelfInScreenCapture)
            }

            if pasteboardAccess.status != .notDetermined {
                Section {
                    PasteboardAccessRow(status: pasteboardAccess.status)
                }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .task(id: appearsActive) {
            if appearsActive {
                pasteboardAccess.refresh()
            }
        }
        .fileImporter(
            isPresented: $isChoosingApps,
            allowedContentTypes: [.application],
            allowsMultipleSelection: true,
            onCompletion: addApps
        )
        .fileDialogDefaultDirectory(URL(filePath: "/Applications", directoryHint: .isDirectory))
        .alert(
            "Some apps can’t be ignored.",
            isPresented: Binding(get: { rejection != nil }, set: {
                if !$0 {
                    rejection = nil
                }
            }),
            presenting: rejection
        ) { _ in
            Button("OK") {}
        } message: { rejection in
            Text(rejection)
        }
    }

    private func addApps(_ result: Result<[URL], any Error>) {
        let urls: [URL]
        do {
            urls = try result.get()
        } catch {
            rejection = error.localizedDescription
            return
        }
        var bundleIDs: [String] = []
        var rejected: [String] = []
        for url in urls {
            if let bundleID = Bundle(url: url)?.bundleIdentifier {
                bundleIDs.append(bundleID)
            } else {
                rejected.append(FileManager.default.displayName(atPath: url.path(percentEncoded: false)))
            }
        }
        privacy.ignoreApps(withBundleIDs: bundleIDs)
        if !rejected.isEmpty {
            rejection = String(
                localized: "\(rejected.formatted(.list(type: .and))) can’t be identified, so Clipsy can’t tell when you copy in them."
            )
        }
    }

    private func removeSelectedApps() {
        privacy.stopIgnoringApps(withBundleIDs: selection)
        selection = []
    }
}

private struct PasteboardAccessRow: View {
    let status: PasteboardAccessStatus
    @Environment(\.openURL) private var openURL

    var body: some View {
        LabeledContent {
            if status == .allowed {
                PermissionStatusLabel(isAllowed: true)
            } else {
                Button("Open System Settings…") {
                    openURL(PasteboardAccess.systemSettingsURL)
                }
            }
        } label: {
            Text("Clipboard Access")
            if status == .allowed {
                Text("Clipsy can read what you copy in other apps.")
            } else if status == .denied {
                Text("Not allowed. Clipsy can’t add what you copy in other apps to your history.")
            } else {
                Text(
                    "macOS asks before Clipsy reads what you copy in other apps. Allow it in Privacy & Security › Paste from Other Apps."
                )
            }
        }
    }
}

private struct IgnoredAppRow: View {
    let bundleID: String
    @State private var app: InstalledApp?

    var body: some View {
        Label {
            Text(app?.name ?? bundleID)
        } icon: {
            if let icon = app?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: DesignTokens.settingsListIconSize, height: DesignTokens.settingsListIconSize)
            } else {
                Image(systemName: "app.dashed")
            }
        }
        .task(id: bundleID) {
            app = InstalledApp(bundleID: bundleID)
        }
    }
}

private struct InstalledApp {
    let name: String
    let icon: NSImage

    init?(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let path = url.path(percentEncoded: false)
        name = FileManager.default.displayName(atPath: path)
        icon = NSWorkspace.shared.icon(forFile: path)
    }
}

#Preview {
    PrivacySettingsView()
        .environment(PrivacySettings())
        .environment(PasteboardAccess(pasteboard: NSPasteboard.withUniqueName()))
}
