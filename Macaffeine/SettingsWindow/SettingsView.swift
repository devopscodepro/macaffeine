import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.needsApproval
    @State private var newHours = 0
    @State private var newMinutes = 45

    private var newPresetMinutes: Int {
        newHours * 60 + newMinutes
    }

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: {
                        LaunchAtLogin.setEnabled($0)
                        refreshLoginState()
                    }
                ))
                if needsApproval {
                    Text("Allow Macaffeine in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(settings.presets, id: \.self) { minutes in
                    presetRow(minutes)
                }
                addPresetRow
            } header: {
                Text("Active for Duration")
            } footer: {
                HStack {
                    Text("Indefinite is always available.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restore Defaults") {
                        settings.restoreDefaultPresets()
                    }
                    .disabled(settings.presets == AwakeDuration.defaultPresets)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 572)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            refreshLoginState()
        }
    }

    private func presetRow(_ minutes: Int) -> some View {
        let title = AwakeDuration.minutes(minutes).title
        return HStack {
            Text(title)
            Spacer()
            Button {
                settings.removePreset(minutes: minutes)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove")
            .accessibilityLabel(Text("Remove \(title)"))
        }
    }

    private var addPresetRow: some View {
        HStack {
            Picker("Hours", selection: $newHours) {
                ForEach(0...24, id: \.self) { Text("\($0) h").tag($0) }
            }
            .labelsHidden()
            .fixedSize()

            Picker("Minutes", selection: $newMinutes) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) min").tag($0) }
            }
            .labelsHidden()
            .fixedSize()

            Spacer()

            Button("Add") {
                settings.addPreset(minutes: newPresetMinutes)
            }
            .disabled(!settings.canAddPreset(minutes: newPresetMinutes))
        }
    }

    private func refreshLoginState() {
        launchAtLogin = LaunchAtLogin.isEnabled
        needsApproval = LaunchAtLogin.needsApproval
    }
}
