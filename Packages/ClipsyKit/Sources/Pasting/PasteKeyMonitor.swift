import AppKit

@MainActor
public protocol PasteKeyMonitoring {
    func start(onPress: @escaping @MainActor () -> Void)
    func stop()
}

/// sees ⌘V in other apps; macOS delivers global key events only while the app is trusted for Accessibility
@MainActor
public final class PasteKeyMonitor: PasteKeyMonitoring {
    private var monitor: Any?

    public init() {}

    public func start(onPress: @escaping @MainActor () -> Void) {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                if Self.isPasteKeystroke(
                    keyCode: event.keyCode,
                    modifierFlags: event.modifierFlags,
                    commandVKeyCode: KeyCodeResolver.commandVKeyCode()
                ) {
                    onPress()
                }
            }
        }
    }

    public func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    /// ⇧ and ⌥ still paste (for example Paste and Match Style), ⌃ turns ⌘V into another command
    static func isPasteKeystroke(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        commandVKeyCode: CGKeyCode
    ) -> Bool {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        return keyCode == commandVKeyCode && flags.contains(.command) && flags.contains(.control) == false
    }
}
