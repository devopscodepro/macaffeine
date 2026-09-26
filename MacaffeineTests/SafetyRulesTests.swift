import Testing
@testable import Macaffeine

struct SafetyRulesTests {
    let rules = SafetyRules(batteryThreshold: 20, stopInLowPowerMode: true, stopWhenOverheating: true)

    @Test func nothingToStopOnNormalPower() {
        #expect(rules.stopReason(for: PowerConditions()) == nil)
    }

    @Test func stopsBelowThresholdOnBattery() {
        let conditions = PowerConditions(isOnBattery: true, batteryLevel: 19)

        #expect(rules.stopReason(for: conditions) == .lowBattery(threshold: 20))
    }

    @Test func keepsGoingAtThreshold() {
        #expect(rules.stopReason(for: PowerConditions(isOnBattery: true, batteryLevel: 20)) == nil)
    }

    @Test func ignoresLowBatteryWhenCharging() {
        #expect(rules.stopReason(for: PowerConditions(isOnBattery: false, batteryLevel: 5)) == nil)
    }

    @Test func ignoresUnknownBatteryLevel() {
        #expect(rules.stopReason(for: PowerConditions(isOnBattery: true, batteryLevel: nil)) == nil)
    }

    @Test func batteryRuleCanBeOff() {
        var rules = rules
        rules.batteryThreshold = nil

        #expect(rules.stopReason(for: PowerConditions(isOnBattery: true, batteryLevel: 5)) == nil)
    }

    @Test func lowPowerMode() {
        #expect(rules.stopReason(for: PowerConditions(isLowPowerMode: true)) == .lowPowerMode)

        var rules = rules
        rules.stopInLowPowerMode = false
        #expect(rules.stopReason(for: PowerConditions(isLowPowerMode: true)) == nil)
    }

    @Test func overheatingWinsOverEverything() {
        let conditions = PowerConditions(isOnBattery: true, batteryLevel: 5, isLowPowerMode: true, isOverheating: true)

        #expect(rules.stopReason(for: conditions) == .overheating)
    }

    @Test func overheatingRuleCanBeOff() {
        var rules = rules
        rules.stopWhenOverheating = false

        #expect(rules.stopReason(for: PowerConditions(isOverheating: true)) == nil)
    }
}
