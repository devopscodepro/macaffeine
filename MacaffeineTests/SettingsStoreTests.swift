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
}
