import AppKit
import Carbon.HIToolbox

struct HotKeyCombo: Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags

    static let `default` = HotKeyCombo(keyCode: UInt16(kVK_ANSI_K), modifiers: [.control, .option, .command])
    static let relevantModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantModifiers)
    }

    // nil when the combination would be too easy to hit while typing
    init?(event: NSEvent) {
        let combo = HotKeyCombo(keyCode: event.keyCode, modifiers: event.modifierFlags)
        guard combo.isValid else { return nil }
        self = combo
    }

    var isValid: Bool {
        if Self.functionKeys.keys.contains(Int(keyCode)) { return true }
        return !modifiers.intersection([.control, .option, .command]).isEmpty
    }

    var carbonModifiers: UInt32 {
        var result = 0
        if modifiers.contains(.control) { result |= controlKey }
        if modifiers.contains(.option) { result |= optionKey }
        if modifiers.contains(.shift) { result |= shiftKey }
        if modifiers.contains(.command) { result |= cmdKey }
        return UInt32(result)
    }

    // keyboard layout APIs only work on the main thread
    @MainActor
    var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + keyName
    }

    // what NSMenuItem.keyEquivalent expects
    @MainActor
    var keyEquivalent: String {
        Self.specialEquivalents[Int(keyCode)] ?? keyName.lowercased()
    }

    @MainActor
    var keyName: String {
        if let name = Self.functionKeys[Int(keyCode)] ?? Self.specialNames[Int(keyCode)] {
            return name
        }
        return Self.character(for: keyCode)?.uppercased() ?? "?"
    }

    private static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    private static let specialNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    ]

    private static let specialEquivalents: [Int: String] = [
        kVK_Space: " ", kVK_Return: "\r", kVK_Tab: "\t",
        kVK_LeftArrow: String(UnicodeScalar(NSLeftArrowFunctionKey)!),
        kVK_RightArrow: String(UnicodeScalar(NSRightArrowFunctionKey)!),
        kVK_UpArrow: String(UnicodeScalar(NSUpArrowFunctionKey)!),
        kVK_DownArrow: String(UnicodeScalar(NSDownArrowFunctionKey)!),
        kVK_F1: String(UnicodeScalar(NSF1FunctionKey)!), kVK_F2: String(UnicodeScalar(NSF2FunctionKey)!),
        kVK_F3: String(UnicodeScalar(NSF3FunctionKey)!), kVK_F4: String(UnicodeScalar(NSF4FunctionKey)!),
        kVK_F5: String(UnicodeScalar(NSF5FunctionKey)!), kVK_F6: String(UnicodeScalar(NSF6FunctionKey)!),
        kVK_F7: String(UnicodeScalar(NSF7FunctionKey)!), kVK_F8: String(UnicodeScalar(NSF8FunctionKey)!),
        kVK_F9: String(UnicodeScalar(NSF9FunctionKey)!), kVK_F10: String(UnicodeScalar(NSF10FunctionKey)!),
        kVK_F11: String(UnicodeScalar(NSF11FunctionKey)!), kVK_F12: String(UnicodeScalar(NSF12FunctionKey)!),
    ]

    // the Latin layout, so ⌘K shows as K even when Russian is the active input source
    @MainActor
    private static func character(for keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }

        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer -> String? in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
            var deadKeys: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                layout, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars
            )
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }
}
