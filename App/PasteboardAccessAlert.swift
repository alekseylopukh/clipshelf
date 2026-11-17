import AppKit
import Capture

enum PasteboardAccessAlert {
    static func presentIfNeeded(access: PasteboardAccess) {
        guard access.takeExplanationRequest() else { return }
        let alert = NSAlert()
        alert.messageText = String(
            localized: "Allow Clipsy to read what you copy?",
            comment: "Title of the alert shown when macOS asks before or blocks Clipsy's clipboard access"
        )
        alert.informativeText = String(
            localized: "macOS asks before Clipsy reads what you copy in other apps, or doesn’t let it read at all, so your history may miss items. Allow Clipsy in System Settings › Privacy & Security › Paste from Other Apps.",
            comment: "Body of the alert shown when macOS asks before or blocks Clipsy's clipboard access"
        )
        alert.addButton(withTitle: String(localized: "Open System Settings…"))
        alert.addButton(withTitle: String(
            localized: "Not Now",
            comment: "Button that skips a permission request for now"
        ))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = String(localized: "Don’t ask again")
        NSApplication.shared.activate()
        let response = alert.runModal()
        if alert.suppressionButton?.state == .on {
            access.suppressExplanation()
        }
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(PasteboardAccess.systemSettingsURL)
        }
    }
}
