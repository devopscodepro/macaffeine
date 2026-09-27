import Foundation
import Testing
@testable import Macaffeine

@MainActor
struct SettingsStoreTests {
    let defaults: UserDefaults

    init() {
        let suite = "SettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func defaultsToIndefiniteAndDefaultPresets() {
        let store = SettingsStore(defaults: defaults)

        #expect(store.duration == .indefinite)
        #expect(store.presets == AwakeDuration.defaultPresets)
        #expect(store.durations.first == .indefinite)
        #expect(store.durations.count == AwakeDuration.defaultPresets.count + 1)
    }

    @Test func persistsDuration() {
        SettingsStore(defaults: defaults).duration = .minutes(120)

        #expect(SettingsStore(defaults: defaults).duration == .minutes(120))
    }

    @Test func addedPresetIsSortedAndPersisted() {
        SettingsStore(defaults: defaults).addPreset(minutes: 45)

        let presets = SettingsStore(defaults: defaults).presets
        #expect(presets.contains(45))
        #expect(presets == presets.sorted())
    }

    @Test func rejectsDuplicateAndOutOfRangePresets() {
        let store = SettingsStore(defaults: defaults)

        #expect(!store.canAddPreset(minutes: 30))
        #expect(!store.canAddPreset(minutes: 0))
        #expect(!store.canAddPreset(minutes: AwakeDuration.maxMinutes + 1))
        #expect(store.canAddPreset(minutes: AwakeDuration.maxMinutes))
    }

    @Test func removingSelectedPresetFallsBackToIndefinite() {
        let store = SettingsStore(defaults: defaults)
        store.duration = .minutes(30)

        store.removePreset(minutes: 30)

        #expect(!store.presets.contains(30))
        #expect(store.duration == .indefinite)
    }

    @Test func restoreDefaults() {
        let store = SettingsStore(defaults: defaults)
        store.addPreset(minutes: 45)
        store.duration = .minutes(45)

        store.restoreDefaultPresets()

        #expect(store.presets == AwakeDuration.defaultPresets)
        #expect(store.duration == .indefinite)
    }

    @Test func cleansUpStoredGarbage() {
        defaults.set([30, 0, -5, 30, 5000, 10], forKey: "presets")

        #expect(SettingsStore(defaults: defaults).presets == [10, 30])
    }

    @Test func persistsKeepDisplayOn() {
        #expect(!SettingsStore(defaults: defaults).keepDisplayOn)

        SettingsStore(defaults: defaults).keepDisplayOn = true

        #expect(SettingsStore(defaults: defaults).keepDisplayOn)
    }

    @Test func safetyRulesDefaultOn() {
        let rules = SettingsStore(defaults: defaults).safetyRules

        #expect(rules == SafetyRules(batteryThreshold: 20, stopInLowPowerMode: true, stopWhenOverheating: true))
    }

    @Test func persistsSafetySettings() {
        let store = SettingsStore(defaults: defaults)
        store.batteryGuard = false
        store.batteryThreshold = 40
        store.stopInLowPowerMode = false
        store.stopWhenOverheating = false

        let reloaded = SettingsStore(defaults: defaults)
        #expect(!reloaded.batteryGuard)
        #expect(reloaded.batteryThreshold == 40)
        #expect(reloaded.safetyRules == SafetyRules(batteryThreshold: nil, stopInLowPowerMode: false, stopWhenOverheating: false))
    }

    @Test func invalidThresholdFallsBackToDefault() {
        defaults.set(7, forKey: "batteryThreshold")

        #expect(SettingsStore(defaults: defaults).batteryThreshold == 20)
    }

    @Test func screenLockStopIsOffByDefault() {
        #expect(!SettingsStore(defaults: defaults).stopOnScreenLock)

        SettingsStore(defaults: defaults).stopOnScreenLock = true

        #expect(SettingsStore(defaults: defaults).stopOnScreenLock)
    }

    @Test func countdownIsOffByDefault() {
        #expect(!SettingsStore(defaults: defaults).showsCountdown)
    }

    @Test func hotKeyDefaultsToCtrlOptCmdK() {
        #expect(SettingsStore(defaults: defaults).hotKey == .default)
    }

    @Test func persistsCustomHotKey() {
        let combo = HotKeyCombo(keyCode: 3, modifiers: [.command, .shift])
        SettingsStore(defaults: defaults).hotKey = combo

        #expect(SettingsStore(defaults: defaults).hotKey == combo)
    }

    @Test func persistsDisabledHotKey() {
        SettingsStore(defaults: defaults).hotKey = nil

        #expect(SettingsStore(defaults: defaults).hotKey == nil)
    }

    @Test func invalidStoredHotKeyFallsBackToDefault() {
        defaults.set(40, forKey: "hotKeyCode")
        defaults.set(0, forKey: "hotKeyModifiers")

        #expect(SettingsStore(defaults: defaults).hotKey == .default)
    }

    @Test func stopAfterSleepIsOnByDefault() {
        #expect(SettingsStore(defaults: defaults).stopAfterSleep)

        SettingsStore(defaults: defaults).stopAfterSleep = false

        #expect(!SettingsStore(defaults: defaults).stopAfterSleep)
    }
}
