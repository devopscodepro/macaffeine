import AppKit
import Carbon.HIToolbox
import Testing
@testable import Macaffeine

@MainActor
struct HotKeyComboTests {
    @Test func defaultCombo() {
        let combo = HotKeyCombo.default

        #expect(combo.displayString == "⌃⌥⌘K")
        #expect(combo.keyEquivalent == "k")
        #expect(combo.carbonModifiers == UInt32(controlKey | optionKey | cmdKey))
    }

    @Test func modifierOrderFollowsMacConvention() {
        let combo = HotKeyCombo(keyCode: UInt16(kVK_ANSI_A), modifiers: [.command, .shift, .option, .control])

        #expect(combo.displayString == "⌃⌥⇧⌘A")
    }

    @Test func ignoresUnrelatedFlags() {
        let combo = HotKeyCombo(keyCode: UInt16(kVK_ANSI_K), modifiers: [.command, .capsLock, .numericPad])

        #expect(combo.modifiers == .command)
    }

    @Test func needsARealModifier() {
        #expect(!HotKeyCombo(keyCode: UInt16(kVK_ANSI_K), modifiers: []).isValid)
        #expect(!HotKeyCombo(keyCode: UInt16(kVK_ANSI_K), modifiers: .shift).isValid)
        #expect(HotKeyCombo(keyCode: UInt16(kVK_ANSI_K), modifiers: .option).isValid)
    }

    @Test func functionKeysWorkAlone() {
        let combo = HotKeyCombo(keyCode: UInt16(kVK_F13), modifiers: [])

        #expect(combo.isValid)
        #expect(combo.displayString == "F13")
    }

    @Test func specialKeys() {
        #expect(HotKeyCombo(keyCode: UInt16(kVK_Space), modifiers: .control).displayString == "⌃Space")
        #expect(HotKeyCombo(keyCode: UInt16(kVK_Space), modifiers: .control).keyEquivalent == " ")
    }
}
