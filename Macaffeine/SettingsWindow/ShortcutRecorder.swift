import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutRecorder: View {
    @ObservedObject var settings: SettingsStore
    @State private var monitor: Any?

    private var isRecording: Bool { settings.isRecordingHotKey }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isRecording ? stop() : start()
            } label: {
                Text(isRecording ? String(localized: "Type shortcut…") : settings.hotKey?.displayString ?? String(localized: "None"))
                    .frame(minWidth: 90)
            }
            .help(isRecording ? "Press Esc to cancel, Delete to turn the shortcut off" : "Click to record a new shortcut")

            if !isRecording, settings.hotKey != .default {
                Button {
                    settings.hotKey = .default
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Reset to \(HotKeyCombo.default.displayString)")
                .accessibilityLabel(Text("Reset shortcut"))
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        settings.isRecordingHotKey = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let key = Int(event.keyCode)
            let plain = event.modifierFlags.intersection(HotKeyCombo.relevantModifiers).isEmpty
            switch key {
            case kVK_Escape:
                stop()
            case kVK_Delete where plain, kVK_ForwardDelete where plain:
                settings.hotKey = nil
                stop()
            default:
                if let combo = HotKeyCombo(event: event) {
                    settings.hotKey = combo
                    stop()
                } else {
                    NSSound.beep()
                }
            }
            return nil
        }
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        settings.isRecordingHotKey = false
    }
}
