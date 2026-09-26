import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let duration = "durationMinutes"
        static let presets = "presets"
        static let keepDisplayOn = "keepDisplayOn"
        static let batteryGuard = "batteryGuard"
        static let batteryThreshold = "batteryThreshold"
        static let stopInLowPowerMode = "stopInLowPowerMode"
        static let stopWhenOverheating = "stopWhenOverheating"
        static let notifyOnAutoStop = "notifyOnAutoStop"
    }

    static let batteryThresholds = [10, 15, 20, 25, 30, 40, 50]

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

    @Published var batteryGuard: Bool {
        didSet { defaults.set(batteryGuard, forKey: Key.batteryGuard) }
    }

    @Published var batteryThreshold: Int {
        didSet { defaults.set(batteryThreshold, forKey: Key.batteryThreshold) }
    }

    @Published var stopInLowPowerMode: Bool {
        didSet { defaults.set(stopInLowPowerMode, forKey: Key.stopInLowPowerMode) }
    }

    @Published var stopWhenOverheating: Bool {
        didSet { defaults.set(stopWhenOverheating, forKey: Key.stopWhenOverheating) }
    }

    @Published var notifyOnAutoStop: Bool {
        didSet { defaults.set(notifyOnAutoStop, forKey: Key.notifyOnAutoStop) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let stored = defaults.array(forKey: Key.presets) as? [Int]
        presets = stored.map(Self.normalized) ?? AwakeDuration.defaultPresets
        duration = AwakeDuration(storedMinutes: defaults.integer(forKey: Key.duration))
        keepDisplayOn = defaults.bool(forKey: Key.keepDisplayOn)
        // safety rules are on unless the user turned them off
        batteryGuard = defaults.object(forKey: Key.batteryGuard) as? Bool ?? true
        let threshold = defaults.integer(forKey: Key.batteryThreshold)
        batteryThreshold = Self.batteryThresholds.contains(threshold) ? threshold : 20
        stopInLowPowerMode = defaults.object(forKey: Key.stopInLowPowerMode) as? Bool ?? true
        stopWhenOverheating = defaults.object(forKey: Key.stopWhenOverheating) as? Bool ?? true
        notifyOnAutoStop = defaults.bool(forKey: Key.notifyOnAutoStop)
    }

    var safetyRules: SafetyRules {
        SafetyRules(
            batteryThreshold: batteryGuard ? batteryThreshold : nil,
            stopInLowPowerMode: stopInLowPowerMode,
            stopWhenOverheating: stopWhenOverheating
        )
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
