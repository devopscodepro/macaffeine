import Foundation
import Testing
@testable import Macaffeine

struct MenuStatusTests {
    let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    func status(_ state: AwakeState, _ reason: StopReason? = nil) -> MenuStatus {
        MenuStatus(state: state, stopReason: reason, now: now, timeFormatter: formatter)
    }

    @Test func inactive() {
        let status = status(.inactive)

        #expect(status.tone == .idle)
        #expect(status.title == "Your Mac can sleep")
        #expect(status.detail == "Choose a duration or press ⌃⌥⌘K")
    }

    @Test func indefinite() {
        let status = status(.active(until: nil))

        #expect(status.tone == .active)
        #expect(status.title == "Keeping your Mac awake")
        #expect(status.detail == "Until you turn it off")
    }

    @Test func timed() {
        let until = now.addingTimeInterval(6120)

        #expect(status(.active(until: until)).detail == "1h 42m remaining · until \(formatter.string(from: until))")
    }

    @Test func expired() {
        let status = status(.inactive, .expired(at: now))

        #expect(status.tone == .idle)
        #expect(status.detail == "Timer finished at \(formatter.string(from: now))")
    }

    @Test(arguments: [StopReason.lowBattery(threshold: 20), .lowPowerMode, .overheating])
    func safetyStopsAreWarnings(reason: StopReason) {
        #expect(status(.inactive, reason).tone == .warning)
    }

    @Test func lowBatteryMentionsThreshold() {
        #expect(status(.inactive, .lowBattery(threshold: 20)).detail.contains("20%"))
    }

    @Test func assertionFailureIsError() {
        #expect(status(.inactive, .assertionFailed).tone == .error)
    }

    @Test func singleHoldShowsLabel() {
        let status = MenuStatus(state: .inactive, holds: [Hold(id: "1", label: "make")], stopReason: nil, now: now)

        #expect(status.tone == .active)
        #expect(status.detail == "While make is running")
    }

    @Test func severalHolds() {
        let status = MenuStatus(state: .inactive, holds: [Hold(id: "1"), Hold(id: "2")], stopReason: nil, now: now)

        #expect(status.detail == "For 2 tasks")
    }

    @Test func sessionTextWinsOverHolds() {
        let status = MenuStatus(state: .active(until: nil), holds: [Hold(id: "1", label: "make")], stopReason: nil, now: now)

        #expect(status.detail == "Until you turn it off")
    }

    @Test func offButOthersKeepAwake() {
        let status = MenuStatus(state: .inactive, stopReason: nil, othersKeepAwake: true, now: now)

        #expect(status.title == "Macaffeine is off")
        #expect(status.detail == "Other apps are keeping your Mac awake")
    }

    @Test func stopReasonWinsOverOthers() {
        let status = MenuStatus(state: .inactive, stopReason: .lowPowerMode, othersKeepAwake: true, now: now)

        #expect(status.tone == .warning)
    }
}
