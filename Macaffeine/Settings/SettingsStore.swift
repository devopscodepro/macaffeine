import AppKit

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
        static let stopOnScreenLock = "stopOnScreenLock"
        static let showsCountdown = "showsCountdown"
        static let stopAfterSleep = "stopAfterSleep"
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let hotKeyDisabled = "hotKeyDisabled"
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

    @Published var stopOnScreenLock: Bool {
        didSet { defaults.set(stopOnScreenLock, forKey: Key.stopOnScreenLock) }
    }

    @Published var stopAfterSleep: Bool {
        didSet { defaults.set(stopAfterSleep, forKey: Key.stopAfterSleep) }
    }

    @Published var showsCountdown: Bool {
        didSet { defaults.set(showsCountdown, forKey: Key.showsCountdown) }
    }

    // nil means the user turned the shortcut off
    @Published var hotKey: HotKeyCombo? {
        didSet {
            defaults.set(hotKey == nil, forKey: Key.hotKeyDisabled)
            if let hotKey {
                defaults.set(Int(hotKey.keyCode), forKey: Key.hotKeyCode)
                defaults.set(Int(hotKey.modifiers.rawValue), forKey: Key.hotKeyModifiers)
            }
        }
    }

    // not saved: set while the recorder listens, so the current shortcut doesn't fire
    @Published var isRecordingHotKey = false
    @Published var hotKeyUnavailable = false

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
        stopOnScreenLock = defaults.bool(forKey: Key.stopOnScreenLock)
        showsCountdown = defaults.bool(forKey: Key.showsCountdown)
        stopAfterSleep = defaults.object(forKey: Key.stopAfterSleep) as? Bool ?? true
        hotKey = Self.loadHotKey(from: defaults)
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

    private static func loadHotKey(from defaults: UserDefaults) -> HotKeyCombo? {
        if defaults.bool(forKey: Key.hotKeyDisabled) {
            return nil
        }
        guard defaults.object(forKey: Key.hotKeyCode) != nil else {
            return .default
        }
        let combo = HotKeyCombo(
            keyCode: UInt16(defaults.integer(forKey: Key.hotKeyCode)),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: Key.hotKeyModifiers)))
        )
        return combo.isValid ? combo : .default
    }

    private static func normalized(_ values: [Int]) -> [Int] {
        Array(Set(values.filter { (1...AwakeDuration.maxMinutes).contains($0) })).sorted()
    }
}
