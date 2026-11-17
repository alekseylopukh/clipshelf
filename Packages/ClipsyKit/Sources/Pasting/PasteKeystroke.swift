// adapted from p0deje/Maccy and TermiT/Flycut (MIT), see THIRD_PARTY_NOTICES.md

import CoreGraphics

@MainActor
public protocol PasteKeystrokePosting {
    func postCommandV()
    func postCommandC()
}

@MainActor
public struct PasteKeystroke: PasteKeystrokePosting {
    /// NX_DEVICELCMDKEYMASK from IOKit's IOLLEvent.h, which Swift does not import
    static let leftCommandDeviceFlag = CGEventFlags(rawValue: 0x0000_0008)

    public init() {}

    public func postCommandV() {
        post(keyCode: KeyCodeResolver.commandVKeyCode())
    }

    public func postCommandC() {
        post(keyCode: KeyCodeResolver.commandCKeyCode())
    }

    private func post(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        for event in Self.commandEvents(keyCode: keyCode, source: source) {
            event.post(tap: .cgSessionEventTap)
        }
    }

    static func commandEvents(keyCode: CGKeyCode, source: CGEventSource?) -> [CGEvent] {
        [true, false].compactMap { keyDown in
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
            event?.flags = [.maskCommand, leftCommandDeviceFlag]
            return event
        }
    }
}
