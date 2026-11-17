import CoreGraphics
import Testing
@testable import Pasting

@MainActor
struct PasteKeystrokeTests {
    @Test func `command V is a key down then key up with left command`() {
        let events = PasteKeystroke.commandVEvents(keyCode: 9, source: nil)

        #expect(events.map(\.type) == [.keyDown, .keyUp])
        for event in events {
            #expect(event.getIntegerValueField(.keyboardEventKeycode) == 9)
            #expect(event.flags.contains([.maskCommand, PasteKeystroke.leftCommandDeviceFlag]))
        }
    }
}
