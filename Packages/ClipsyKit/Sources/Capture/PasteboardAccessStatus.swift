import AppKit

public enum PasteboardAccessStatus: Sendable, Equatable {
    /// macOS has never asked about this app, so it is not listed in System Settings
    case notDetermined
    case ask
    case allowed
    case denied

    public init(_ behavior: NSPasteboard.AccessBehavior) {
        switch behavior {
        case .default: self = .notDetermined
        case .ask: self = .ask
        case .alwaysAllow: self = .allowed
        case .alwaysDeny: self = .denied
        @unknown default: self = .notDetermined
        }
    }

    public var needsExplanation: Bool {
        self == .ask || self == .denied
    }
}
