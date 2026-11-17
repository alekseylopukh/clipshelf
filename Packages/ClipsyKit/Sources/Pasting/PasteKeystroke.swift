// adapted from p0deje/Maccy and TermiT/Flycut (MIT), see THIRD_PARTY_NOTICES.md

import CoreGraphics

@MainActor
public protocol PasteKeystrokePosting {
    func postCommandV()
}

@MainActor
public struct PasteKeystroke: PasteKeystrokePosting {
    /// NX_DEVICELCMDKEYMASK from IOKit's IOLLEvent.h, which Swift does not import
    static let leftCommandDeviceFlag = CGEventFlags(rawValue: 0x0000_0008)

    public init() {}

    public func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        for event in Self.commandVEvents(keyCode: KeyCodeResolver.commandVKeyCode(), source: source) {
            event.post(tap: .cgSessionEventTap)
        }
    }

    static func commandVEvents(keyCode: CGKeyCode, source: CGEventSource?) -> [CGEvent] {
        [true, false].compactMap { keyDown in
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
            event?.flags = [.maskCommand, leftCommandDeviceFlag]
            return event
        }
    }
}
