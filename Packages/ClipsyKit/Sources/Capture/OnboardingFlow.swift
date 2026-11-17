import Foundation
import Observation

public enum OnboardingStep: Sendable {
    case welcome
    case pasteDirectly
    case clipboardAccess
    case finish
}

@MainActor
@Observable
public final class OnboardingFlow {
    public static let wasPresentedKey = "OnboardingPresented"

    public private(set) var step = OnboardingStep.welcome
    /// read once at launch, so marking the window as presented does not hide it while it is open
    public let presentsAtLaunch: Bool

    @ObservationIgnored public let access: PasteboardAccess
    @ObservationIgnored private let defaults: UserDefaults

    public init(access: PasteboardAccess, defaults: UserDefaults = .standard) {
        self.access = access
        self.defaults = defaults
        presentsAtLaunch = !defaults.bool(forKey: Self.wasPresentedKey)
    }

    public func markPresented() {
        defaults.set(true, forKey: Self.wasPresentedKey)
    }

    public func advance() {
        switch step {
        case .welcome:
            step = .pasteDirectly
        case .pasteDirectly:
            access.refresh()
            step = access.status.needsExplanation ? .clipboardAccess : .finish
        case .clipboardAccess:
            step = .finish
        case .finish:
            break
        }
    }
}
