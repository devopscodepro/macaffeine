import SwiftUI

struct SafetySettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.batteryGuard) {
                    Text("Stop when battery is low")
                    Text("Only while running on battery.")
                }
                Picker("Battery level", selection: $settings.batteryThreshold) {
                    ForEach(SettingsStore.batteryThresholds, id: \.self) { Text("Below \($0)%").tag($0) }
                }
                .disabled(!settings.batteryGuard)
            }

            Section {
                Toggle(isOn: $settings.stopInLowPowerMode) {
                    Text("Stop in Low Power Mode")
                    Text("Low Power Mode means you want to save energy.")
                }
                Toggle(isOn: $settings.stopWhenOverheating) {
                    Text("Stop when your Mac overheats")
                    Text("When macOS reports a critical temperature, for example in a closed bag.")
                }
            }

            Section {
                Toggle(isOn: $settings.stopAfterSleep) {
                    Text("Stop after your Mac sleeps")
                    Text("When you put it to sleep or close the lid, Keep Awake is off after it wakes up.")
                }
                Toggle(isOn: $settings.stopOnScreenLock) {
                    Text("Stop when you lock your screen")
                    Text("Also when it locks by itself after the display turns off.")
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Commands kept awake with `macaffeine run` or `hold` keep running in both cases.")

                    Text("Closing the lid still puts your Mac to sleep unless it's connected to power and an external display. That's how macOS works, Macaffeine doesn't change it.")
                }
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
