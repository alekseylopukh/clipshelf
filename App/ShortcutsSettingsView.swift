import ShelfUI
import SwiftUI

struct ShortcutsSettingsView: View {
    @Environment(ShortcutSettings.self) private var settings
    @State private var isConfirmingRestore = false

    var body: some View {
        Form {
            Section {
                ForEach(settings.recorders) { recorder in
                    ShortcutRecorderRow(recorder: recorder)
                }
            }

            Section {
                Picker("Quick Paste modifier", selection: Binding(
                    get: { settings.modifiers.quickPaste },
                    set: { settings.setQuickPasteModifier($0) }
                )) {
                    ForEach(QuickPasteModifiers.quickPasteChoices, id: \.self) { key in
                        Text(key.title)
                            .tag(key)
                            .disabled(!settings.isAvailable(quickPaste: key))
                    }
                }
                Picker("Plain text modifier", selection: Binding(
                    get: { settings.modifiers.plainText },
                    set: { settings.setPlainTextModifier($0) }
                )) {
                    ForEach(QuickPasteModifiers.plainTextChoices, id: \.self) { key in
                        Text(key.title)
                            .tag(key)
                            .disabled(!settings.isAvailable(plainText: key))
                    }
                }
            } header: {
                Text("Shelf")
            } footer: {
                HStack {
                    Spacer()
                    Button("Restore Defaults…") {
                        isConfirmingRestore = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .alert("Restore the default shortcuts?", isPresented: $isConfirmingRestore) {
            Button("Restore Defaults") {
                settings.restoreDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All shortcuts and modifiers on this pane return to their default values.")
        }
    }
}

private struct ShortcutRecorderRow: View {
    let recorder: ShortcutSettings.Recorder

    @Environment(ShortcutSettings.self) private var settings

    var body: some View {
        LabeledContent(recorder.title) {
            VStack(alignment: .trailing) {
                KeyboardShortcuts.Recorder(for: recorder.name) { shortcut in
                    settings.recorderDidChange(recorder.name, to: shortcut)
                }
                if let notice = settings.notice(for: recorder.name) {
                    ShortcutNoticeLabel(notice: notice)
                }
            }
        }
    }
}

private struct ShortcutNoticeLabel: View {
    let notice: ShortcutSettings.Notice

    var body: some View {
        Label {
            switch notice {
            case let .conflict(shortcut, usedBy):
                Text("\(shortcut.description) is already used by “\(usedBy)”.")
            case .optionOnly:
                Text("Shortcuts that use only ⌥ as a modifier may not work reliably.")
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.trailing)
    }
}

private extension QuickPasteModifiers.Key {
    var title: LocalizedStringResource {
        switch self {
        case .command: "⌘ Command"
        case .control: "⌃ Control"
        case .option: "⌥ Option"
        case .shift: "⇧ Shift"
        }
    }
}

#Preview {
    ShortcutsSettingsView()
        .environment(ShortcutSettings(store: KeyboardShortcutsStore()))
}
