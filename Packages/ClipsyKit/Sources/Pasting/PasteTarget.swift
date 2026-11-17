import AppKit

@MainActor
public protocol PasteTarget {
    var isActive: Bool { get }
    /// returns once the target is active, or after a short timeout
    func activate() async
}

extension NSRunningApplication: PasteTarget {
    private static let activationPollInterval = Duration.milliseconds(25)
    private static let activationPollLimit = 20

    @MainActor
    public func activate() async {
        guard activate(options: []) else { return }
        var remainingPolls = Self.activationPollLimit
        while !isActive, remainingPolls > 0 {
            remainingPolls -= 1
            do {
                try await Task.sleep(for: Self.activationPollInterval)
            } catch {
                return
            }
        }
    }
}
