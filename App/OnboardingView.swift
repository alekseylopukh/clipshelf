import AppKit
import Capture
import DesignSystem
import Pasting
import ServiceManagement
import ShelfUI
import Store
import SwiftUI

struct OnboardingView: View {
    static let windowID = "onboarding"

    @Environment(OnboardingFlow.self) private var flow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch flow.step {
            case .welcome:
                WelcomeStep()
            case .pasteDirectly:
                PasteDirectlyStep()
            case .clipboardAccess:
                ClipboardAccessStep()
            case .finish:
                FinishStep {
                    dismissWindow(id: Self.windowID)
                }
            }
        }
        .id(flow.step)
        .transition(reduceMotion ? .opacity : AnyTransition(.blurReplace))
        .padding(DesignTokens.onboardingPadding)
        .frame(width: DesignTokens.onboardingWidth, height: DesignTokens.onboardingHeight)
        .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.standard, value: flow.step)
        .onAppear {
            flow.markPresented()
        }
    }
}

private struct OnboardingPage<Icon: View, Content: View, Controls: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder let icon: Icon
    @ViewBuilder let content: Content
    @ViewBuilder let controls: Controls

    var body: some View {
        VStack(spacing: DesignTokens.spacingLarge) {
            icon
                .frame(width: DesignTokens.onboardingHeroSize, height: DesignTokens.onboardingHeroSize)
                .accessibilityHidden(true)
            Text(title)
                .font(.largeTitle.bold())
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: DesignTokens.onboardingMessageWidth)
                .fixedSize(horizontal: false, vertical: true)
            Form {
                content
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            SheetButtonBar {
                controls
            }
            .controlSize(.large)
        }
    }
}

private struct StepSymbol: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
    }
}

private struct WelcomeStep: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        OnboardingPage(
            title: "Welcome to Clipsy",
            message: "Everything you copy, one shortcut away."
        ) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
        } content: {
            KeyboardShortcuts.Recorder("Open Shelf", name: .toggleShelf)
        } controls: {
            Button("Continue", action: flow.advance)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct PasteDirectlyStep: View {
    @Environment(OnboardingFlow.self) private var flow
    @State private var isTrusted = SystemAccessibilityTrust().isTrusted

    var body: some View {
        OnboardingPage(
            title: "Paste Directly",
            message: "To paste into other apps, Clipsy needs Accessibility permission. Without it, Clipsy copies the card and you press ⌘V to paste it."
        ) {
            StepSymbol(systemName: "accessibility")
        } content: {
            LabeledContent("Accessibility") {
                PermissionStatusLabel(isAllowed: isTrusted)
            }
        } controls: {
            if isTrusted {
                Button("Continue", action: flow.advance)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Not Now", action: flow.advance)
                Button("Open System Settings…") {
                    _ = SystemAccessibilityTrust().requestTrust()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .task {
            while !Task.isCancelled {
                isTrusted = SystemAccessibilityTrust().isTrusted
                try? await Task.sleep(for: OnboardingStepTiming.pollInterval)
            }
        }
    }
}

private struct ClipboardAccessStep: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(PasteboardAccess.self) private var access
    @Environment(\.openURL) private var openURL

    var body: some View {
        OnboardingPage(
            title: "Clipboard Access",
            message: "macOS asks before Clipsy reads what you copy in other apps, or doesn’t let it read at all. To keep your history complete, allow Clipsy in System Settings › Privacy & Security › Paste from Other Apps."
        ) {
            StepSymbol(systemName: "doc.on.clipboard")
        } content: {
            LabeledContent("Clipboard Access") {
                PermissionStatusLabel(isAllowed: access.status == .allowed)
            }
        } controls: {
            if access.status == .allowed {
                Button("Continue", action: flow.advance)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Not Now", action: flow.advance)
                Button("Open System Settings…") {
                    openURL(PasteboardAccess.systemSettingsURL)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .task {
            while !Task.isCancelled {
                access.refresh()
                try? await Task.sleep(for: OnboardingStepTiming.pollInterval)
            }
        }
    }
}

private struct FinishStep: View {
    let done: () -> Void

    @Environment(RetentionSettings.self) private var retention
    @Environment(PrivacySettings.self) private var privacy
    @State private var loginItemStatus = SMAppService.mainApp.status
    @State private var shortcut = KeyboardShortcuts.getShortcut(for: .toggleShelf)
    @State private var failure: String?

    var body: some View {
        @Bindable var privacy = privacy
        OnboardingPage(title: "You’re All Set", message: hint) {
            StepSymbol(systemName: "checkmark.circle")
        } content: {
            Toggle("Open at login", isOn: Binding(get: { isOpenAtLoginOn }, set: setOpenAtLogin))
            Picker("Keep history for", selection: Binding(get: { retention.period }, set: select)) {
                ForEach(RetentionPeriod.allCases, id: \.self) { period in
                    Text(period.title)
                }
            }
            Toggle(isOn: $privacy.fetchesLinkPreviews) {
                LabelWithNote(
                    Text("Show link previews"),
                    note: Text(
                        "Clipsy loads each link you copy. This can use up a one-time link or let the site track the visit."
                    )
                )
            }
        } controls: {
            Button("Done", action: done)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .alert(
            "Remove older cards from History?",
            // the buttons clear the pending change; clearing it here would run before the confirm task
            isPresented: Binding(get: { retention.pendingPeriod != nil }, set: { _ in })
        ) {
            Button("Remove Cards", role: .destructive) {
                Task {
                    do {
                        try await retention.confirmPendingChange()
                    } catch {
                        failure = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                retention.cancelPendingChange()
            }
        } message: {
            Text(
                "Cards older than the new limit will be removed from History. Cards on boards are kept. You can’t undo this action."
            )
        }
        .alert(
            "Clipsy can’t change this setting.",
            isPresented: Binding(get: { failure != nil }, set: {
                if !$0 {
                    failure = nil
                }
            }),
            presenting: failure
        ) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
    }

    private var hint: LocalizedStringKey {
        if let shortcut {
            "Press \(shortcut.description) to open the Shelf and try it."
        } else {
            "Set a shortcut in Settings to open the Shelf."
        }
    }

    private var isOpenAtLoginOn: Bool {
        loginItemStatus == .enabled || loginItemStatus == .requiresApproval
    }

    private func setOpenAtLogin(_ isOn: Bool) {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            failure = error.localizedDescription
        }
        loginItemStatus = SMAppService.mainApp.status
    }

    private func select(_ period: RetentionPeriod) {
        Task {
            do {
                try await retention.select(period)
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

private enum OnboardingStepTiming {
    static let pollInterval = Duration.seconds(1)
}
