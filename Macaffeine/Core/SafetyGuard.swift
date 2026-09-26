import Combine
import Foundation

@MainActor
final class SafetyGuard {
    private let manager: AwakeManager
    private let settings: SettingsStore
    private let monitor: PowerMonitor
    private var subscription: AnyCancellable?

    init(manager: AwakeManager, settings: SettingsStore, monitor: PowerMonitor) {
        self.manager = manager
        self.settings = settings
        self.monitor = monitor

        manager.safetyCheck = { [weak self] in self?.currentReason() }
        monitor.onChange = { [weak self] _ in self?.evaluate() }
        // objectWillChange fires before the new value is stored
        subscription = settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.evaluate() }
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
