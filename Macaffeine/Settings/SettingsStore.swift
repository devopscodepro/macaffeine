import Foundation

final class SettingsStore {
    private enum Key {
        static let duration = "duration"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var duration: AwakeDuration {
        get {
            defaults.string(forKey: Key.duration).flatMap(AwakeDuration.init(rawValue:)) ?? .indefinite
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.duration)
        }
    }
}
