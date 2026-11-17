import AppKit
import Observation

@MainActor
@Observable
public final class PasteboardAccess {
    public static let suppressesExplanationKey = "SuppressPasteboardAccessExplanation"
    /// the anchor was found in the macOS 27.2 System Settings; it is not verified on macOS 26
    public static let systemSettingsURL: URL = {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard") else {
            fatalError("the System Settings URL is a valid constant")
        }
        return url
    }()

    public private(set) var status: PasteboardAccessStatus

    @ObservationIgnored private let pasteboard: any PasteboardAccessReading
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var hasExplained = false

    public init(pasteboard: any PasteboardAccessReading = NSPasteboard.general, defaults: UserDefaults = .standard) {
        self.pasteboard = pasteboard
        self.defaults = defaults
        status = PasteboardAccessStatus(pasteboard.accessBehavior)
    }

    public func refresh() {
        status = PasteboardAccessStatus(pasteboard.accessBehavior)
    }

    /// refreshes the status; true at most once per launch, while access needs an explanation and the user has not
    /// suppressed it
    public func takeExplanationRequest() -> Bool {
        refresh()
        guard status.needsExplanation, !hasExplained, !defaults.bool(forKey: Self.suppressesExplanationKey) else {
            return false
        }
        hasExplained = true
        return true
    }

    public func suppressExplanation() {
        defaults.set(true, forKey: Self.suppressesExplanationKey)
    }
}
