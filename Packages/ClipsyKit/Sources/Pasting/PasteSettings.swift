import Foundation

public enum PasteBehavior: String, Sendable, CaseIterable {
    case pasteIntoActiveApp
    case copyOnly
}

public enum PasteSettings {
    public static let behaviorKey = "PasteBehavior"
    public static let plainTextByDefaultKey = "PastePlainTextByDefault"
    public static let accessibilityAlertSuppressedKey = "AccessibilityAlertSuppressed"
}

extension UserDefaults {
    var pasteBehavior: PasteBehavior {
        string(forKey: PasteSettings.behaviorKey).flatMap(PasteBehavior.init(rawValue:)) ?? .pasteIntoActiveApp
    }

    var pastesPlainTextByDefault: Bool {
        bool(forKey: PasteSettings.plainTextByDefaultKey)
    }

    var isAccessibilityAlertSuppressed: Bool {
        get { bool(forKey: PasteSettings.accessibilityAlertSuppressedKey) }
        set { set(newValue, forKey: PasteSettings.accessibilityAlertSuppressedKey) }
    }
}
