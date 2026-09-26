import UserNotifications

@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private var center: UNUserNotificationCenter { .current() }

    override init() {
        super.init()
        center.delegate = self
    }

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert])
        } catch {
            Log.settings.error("Notification permission failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    func isAllowed() async -> Bool {
        await center.notificationSettings().authorizationStatus == .authorized
    }

    func post(for reason: StopReason) {
        guard let text = reason.notificationText else { return }

        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        center.add(UNNotificationRequest(identifier: "auto-stop", content: content, trigger: nil))
    }

    // show the banner even while the settings window is in front
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}

extension StopReason {
    var notificationText: (title: String, body: String)? {
        switch self {
        case .expired:
            (String(localized: "Keep Awake finished"), String(localized: "Your Mac can sleep normally again."))
        case .lowBattery(let threshold):
            (String(localized: "Keep Awake stopped"), String(localized: "Battery is below \(threshold)%, your Mac can sleep again."))
        case .lowPowerMode:
            (String(localized: "Keep Awake stopped"), String(localized: "Low Power Mode is on, your Mac can sleep again."))
        case .overheating:
            (String(localized: "Keep Awake stopped"), String(localized: "Your Mac is too hot, it can sleep again."))
        case .screenLocked:
            (String(localized: "Keep Awake stopped"), String(localized: "You locked the screen, your Mac can sleep again."))
        case .assertionFailed:
            nil
        }
    }
}
