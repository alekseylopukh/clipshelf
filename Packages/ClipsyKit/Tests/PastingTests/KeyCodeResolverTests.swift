import Carbon
import Testing
@testable import Pasting

@MainActor
struct KeyCodeResolverTests {
    private static func layout(_ id: String) throws -> TISInputSource {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]
        return try #require(sources?.first)
    }

    @Test func `key code for V on US layout is 9`() throws {
        let source = try Self.layout("com.apple.keylayout.US")
        #expect(KeyCodeResolver.keyCode(for: "v", in: source, command: true) == 9)
    }

    @Test(arguments: [
        ("com.apple.keylayout.Dvorak", false, CGKeyCode(kVK_ANSI_Period)),
        ("com.apple.keylayout.Dvorak", true, CGKeyCode(kVK_ANSI_Period)),
        ("com.apple.keylayout.DVORAK-QWERTYCMD", false, CGKeyCode(kVK_ANSI_Period)),
        ("com.apple.keylayout.DVORAK-QWERTYCMD", true, CGKeyCode(kVK_ANSI_V))
    ])
    func `key for V follows the layout and its command table`(id: String, command: Bool, expected: CGKeyCode) throws {
        let source = try Self.layout(id)
        #expect(KeyCodeResolver.keyCode(for: "v", in: source, command: command) == expected)
    }
}
