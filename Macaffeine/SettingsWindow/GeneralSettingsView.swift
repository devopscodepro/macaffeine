import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsStore
    let notifier: Notifier

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.needsApproval
    @State private var notificationsBlocked = false
    @State private var copied = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: {
                        LaunchAtLogin.setEnabled($0)
                        refresh()
                    }
                ))
                if needsApproval {
                    Text("Allow Macaffeine in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: $settings.keepDisplayOn) {
                    Text("Keep display on")
                    Text("The screen won't dim or turn off while your Mac is kept awake.")
                }

                LabeledContent("Toggle Keep Awake") {
                    Text("⌃⌥⌘K")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { settings.notifyOnAutoStop },
                    set: { enabled in
                        if enabled {
                            Task { await enableNotifications() }
                        } else {
                            settings.notifyOnAutoStop = false
                        }
                    }
                )) {
                    Text("Notify when Keep Awake stops on its own")
                    Text("When the timer ends or a safety rule turns it off.")
                }
                if notificationsBlocked {
                    HStack {
                        Text("Notifications are turned off for Macaffeine.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open System Settings") {
                            openNotificationSettings()
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keep your Mac awake while a command runs, for example `macaffeine run -- make`. To install it, run this in Terminal:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top) {
                        Text(Self.installCommand)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button(copied ? "Copied" : "Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(Self.installCommand, forType: .string)
                            copied = true
                        }
                        .controlSize(.small)
                    }
                }
            } header: {
                Text("Command Line Tool")
            }

            Section {
                HStack(spacing: 10) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Macaffeine")
                            .fontWeight(.semibold)
                        Text("Version \(Self.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Quit Macaffeine") {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            refresh()
        }
    }

    private static var installCommand: String {
        let path = Bundle.main.url(forResource: "macaffeine", withExtension: nil)?.path ?? "/Applications/Macaffeine.app/Contents/Resources/macaffeine"
        return "sudo mkdir -p /usr/local/bin && sudo ln -sf '\(path)' /usr/local/bin/macaffeine"
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private func refresh() {
        launchAtLogin = LaunchAtLogin.isEnabled
        needsApproval = LaunchAtLogin.needsApproval
        Task {
            notificationsBlocked = settings.notifyOnAutoStop ? !(await notifier.isAllowed()) : false
        }
    }

    private func enableNotifications() async {
        let allowed = await notifier.requestPermission()
        settings.notifyOnAutoStop = allowed
        notificationsBlocked = !allowed
    }

    private func openNotificationSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
    }
}
