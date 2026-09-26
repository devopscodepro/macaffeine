import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let duration = "durationMinutes"
        static let presets = "presets"
        static let keepDisplayOn = "keepDisplayOn"
    }

    private let defaults: UserDefaults

    @Published private(set) var presets: [Int] {
        didSet { defaults.set(presets, forKey: Key.presets) }
    }

    @Published var duration: AwakeDuration {
        didSet { defaults.set(duration.storedMinutes, forKey: Key.duration) }
    }

    @Published var keepDisplayOn: Bool {
        didSet { defaults.set(keepDisplayOn, forKey: Key.keepDisplayOn) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let stored = defaults.array(forKey: Key.presets) as? [Int]
        presets = stored.map(Self.normalized) ?? AwakeDuration.defaultPresets
        duration = AwakeDuration(storedMinutes: defaults.integer(forKey: Key.duration))
        keepDisplayOn = defaults.bool(forKey: Key.keepDisplayOn)
    }

    var durations: [AwakeDuration] {
        [.indefinite] + presets.map(AwakeDuration.minutes)
    }

    func canAddPreset(minutes: Int) -> Bool {
        (1...AwakeDuration.maxMinutes).contains(minutes) && !presets.contains(minutes)
    }

    func addPreset(minutes: Int) {
        guard canAddPreset(minutes: minutes) else { return }
        presets = Self.normalized(presets + [minutes])
    }

    func removePreset(minutes: Int) {
        presets.removeAll { $0 == minutes }
        if duration == .minutes(minutes) {
            duration = .indefinite
        }
    }

    func restoreDefaultPresets() {
        presets = AwakeDuration.defaultPresets
        if case .minutes(let minutes) = duration, !presets.contains(minutes) {
            duration = .indefinite
        }
    }

    private static func normalized(_ values: [Int]) -> [Int] {
        Array(Set(values.filter { (1...AwakeDuration.maxMinutes).contains($0) })).sorted()
    }
}
