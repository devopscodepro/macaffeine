import Foundation

struct PowerConditions: Equatable {
    var isOnBattery = false
    var batteryLevel: Int?
    var isLowPowerMode = false
    var isOverheating = false
}

struct SafetyRules: Equatable {
    var batteryThreshold: Int?
    var stopInLowPowerMode = true
    var stopWhenOverheating = true

    func stopReason(for conditions: PowerConditions) -> StopReason? {
        if stopWhenOverheating, conditions.isOverheating {
            return .overheating
        }
        // no battery or unknown level (desktops) means the rule simply doesn't apply
        if let threshold = batteryThreshold, conditions.isOnBattery,
           let level = conditions.batteryLevel, level < threshold {
            return .lowBattery(threshold: threshold)
        }
        if stopInLowPowerMode, conditions.isLowPowerMode {
            return .lowPowerMode
        }
        return nil
    }
}
