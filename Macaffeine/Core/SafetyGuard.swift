import AppKit
import Combine

@MainActor
final class SafetyGuard {
    private let manager: AwakeManager
    private let settings: SettingsStore
    private let monitor: PowerMonitor
    private var subscription: AnyCancellable?
    private var observers: [NSObjectProtocol] = []

    init(
        manager: AwakeManager,
        settings: SettingsStore,
        monitor: PowerMonitor,
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        distributedCenter: NotificationCenter = DistributedNotificationCenter.default()
    ) {
        self.manager = manager
        self.settings = settings
        self.monitor = monitor

        manager.safetyCheck = { [weak self] in self?.currentReason() }
        monitor.onChange = { [weak self] _ in self?.evaluate() }
        // objectWillChange fires before the new value is stored
        subscription = settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.evaluate() }

        observers.append(distributedCenter.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked() }
        })
        // idle sleep can't happen while we hold the assertion, so any sleep now was asked for
        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.systemWillSleep() }
        })
    }

    private func systemWillSleep() {
        guard settings.stopAfterSleep, manager.isSessionActive else { return }
        Log.awake.info("Mac is going to sleep, ending session")
        manager.stopSession(because: .systemSlept)
    }

    private func screenLocked() {
        guard settings.stopOnScreenLock, manager.isSessionActive else { return }
        Log.awake.info("Screen locked, ending session")
        manager.stopSession(because: .screenLocked)
    }

    private func currentReason() -> StopReason? {
        settings.safetyRules.stopReason(for: monitor.conditions)
    }

    private func evaluate() {
        guard manager.isActive, let reason = currentReason() else { return }
        Log.awake.info("Safety stop: \(String(describing: reason), privacy: .public)")
        manager.stop(because: reason)
    }
}
