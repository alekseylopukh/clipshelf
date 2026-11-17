import Carbon
import CoreGraphics

@MainActor
public enum KeyCodeResolver {
    /// with `command`, layouts such as Dvorak – QWERTY ⌘ resolve to the key the layout uses while ⌘ is held
    public static func keyCode(for character: Character, in source: TISInputSource, command: Bool) -> CGKeyCode? {
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        let target = String(character)
        let modifiers = command ? UInt32(cmdKey >> 8) & 0xFF : 0
        let keyboardType = UInt32(LMGetKbdType())

        return data.withUnsafeBytes { buffer -> CGKeyCode? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return nil
            }
            for keyCode in UInt16(0) ..< 128 {
                var deadKeyState: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout,
                    keyCode,
                    UInt16(kUCKeyActionDown),
                    modifiers,
                    keyboardType,
                    OptionBits(kUCKeyTranslateNoDeadKeysMask),
                    &deadKeyState,
                    characters.count,
                    &length,
                    &characters
                )
                if status == noErr, String(utf16CodeUnits: characters, count: length).lowercased() == target {
                    return CGKeyCode(keyCode)
                }
            }
            return nil
        }
    }

    /// the key code that types ⌘V on the current ASCII-capable layout; the ANSI position when it cannot be resolved
    public static func commandVKeyCode() -> CGKeyCode {
        let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
        return keyCode(for: "v", in: source, command: true) ?? CGKeyCode(kVK_ANSI_V)
    }
}
