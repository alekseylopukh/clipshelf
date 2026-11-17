import AppKit

public struct AccessibilityAlertResponse: Sendable, Equatable {
    public var opensSystemSettings: Bool
    public var suppressesFutureAlerts: Bool

    public init(opensSystemSettings: Bool, suppressesFutureAlerts: Bool) {
        self.opensSystemSettings = opensSystemSettings
        self.suppressesFutureAlerts = suppressesFutureAlerts
    }
}

@MainActor
public protocol AccessibilityAlertPresenting {
    func presentAccessibilityAlert() -> AccessibilityAlertResponse
}

@MainActor
public struct AccessibilityAlert: AccessibilityAlertPresenting {
    public init() {}

    public func presentAccessibilityAlert() -> AccessibilityAlertResponse {
        let alert = NSAlert()
        alert.messageText = String(
            localized: "Allow Clipsy to paste into other apps?",
            comment: "Title of the alert shown on the first paste without Accessibility permission"
        )
        alert.informativeText = String(
            localized: "To paste directly, Clipsy needs Accessibility permission in Privacy & Security settings. Until then, Clipsy copies the card and you can press ⌘V to paste it.",
            comment: "Body of the alert shown on the first paste without Accessibility permission"
        )
        alert.addButton(withTitle: String(
            localized: "Open System Settings…",
            comment: "Alert button that asks macOS for Accessibility permission"
        ))
        alert.addButton(withTitle: String(
            localized: "Copy Only",
            comment: "Alert button that keeps the card on the clipboard without pasting"
        ))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = String(
            localized: "Don’t ask again",
            comment: "Checkbox in the Accessibility alert that stops it from appearing"
        )
        NSApplication.shared.activate()
        let response = alert.runModal()
        return AccessibilityAlertResponse(
            opensSystemSettings: response == .alertFirstButtonReturn,
            suppressesFutureAlerts: alert.suppressionButton?.state == .on
        )
    }
}
