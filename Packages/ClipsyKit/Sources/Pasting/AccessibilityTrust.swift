import ApplicationServices

@MainActor
public protocol AccessibilityTrust {
    var isTrusted: Bool { get }
    /// shows the system Accessibility prompt when the app is not trusted yet
    @discardableResult
    func requestTrust() -> Bool
}

@MainActor
public struct SystemAccessibilityTrust: AccessibilityTrust {
    /// value of kAXTrustedCheckOptionPrompt, which Swift imports as a mutable global that strict concurrency rejects
    private static let promptOption = "AXTrustedCheckOptionPrompt"

    public init() {}

    public var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    public func requestTrust() -> Bool {
        AXIsProcessTrustedWithOptions([Self.promptOption: true] as CFDictionary)
    }
}
