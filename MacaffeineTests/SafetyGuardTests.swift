import AppKit
import Testing
@testable import Macaffeine

@MainActor
struct SafetyGuardTests {
    let assertion = MockPowerAssertionManager()
    let workspace = NotificationCenter()
    let distributed = NotificationCenter()
    let settings: SettingsStore
    let manager: AwakeManager
    let safetyGuard: SafetyGuard

    init() {
        let suite = "SafetyGuardTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        settings = SettingsStore(defaults: defaults)
        // keep the real battery state of the test machine out of it
        settings.batteryGuard = false
        settings.stopInLowPowerMode = false
        settings.stopWhenOverheating = false

        manager = AwakeManager(
            assertion: assertion,
            scheduler: MockExpirationScheduler(),
            makeHoldScheduler: { MockExpirationScheduler() },
            processWatcher: MockProcessWatcher()
        )
        safetyGuard = SafetyGuard(
            manager: manager,
            settings: settings,
            monitor: PowerMonitor(),
            workspaceCenter: workspace,
            distributedCenter: distributed
        )
    }

    func sleep() {
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
    }

    func lockScreen() {
        distributed.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)
    }

    @Test func sleepEndsSessionByDefault() {
        manager.activate()

        sleep()

        #expect(!manager.isActive)
        #expect(manager.stopReason == .systemSlept)
    }

    @Test func sleepKeepsHolds() {
        manager.activate()
        manager.hold(Hold(id: "build"))

        sleep()

        #expect(!manager.isSessionActive)
        #expect(manager.holds.count == 1)
        #expect(assertion.isHeld)
    }

    @Test func sleepRuleCanBeOff() {
        settings.stopAfterSleep = false
        manager.activate()

        sleep()

        #expect(manager.isSessionActive)
    }

    @Test func lockIsIgnoredByDefault() {
        manager.activate()

        lockScreen()

        #expect(manager.isSessionActive)
    }

    @Test func lockEndsSessionWhenEnabled() {
        settings.stopOnScreenLock = true
        manager.activate()

        lockScreen()

        #expect(manager.stopReason == .screenLocked)
    }
}
