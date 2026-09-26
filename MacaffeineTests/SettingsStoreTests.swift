import Foundation
import Testing
@testable import Macaffeine

struct SettingsStoreTests {
    let defaults: UserDefaults

    init() {
        let suite = "SettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func defaultsToIndefinite() {
        #expect(SettingsStore(defaults: defaults).duration == .indefinite)
    }

    @Test func persistsDuration() {
        SettingsStore(defaults: defaults).duration = .hours2

        #expect(SettingsStore(defaults: defaults).duration == .hours2)
    }

    @Test func ignoresUnknownValue() {
        defaults.set("forever", forKey: "duration")

        #expect(SettingsStore(defaults: defaults).duration == .indefinite)
    }
}
