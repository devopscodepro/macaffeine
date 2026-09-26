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

    @Test func inactive() {
        let status = MenuStatus(state: .inactive, now: now, timeFormatter: formatter)

        #expect(status.title == "Your Mac can sleep")
        #expect(status.detail == "Choose a duration or press ⌃⌥⌘K")
    }

    @Test func indefinite() {
        let status = MenuStatus(state: .active(until: nil), now: now, timeFormatter: formatter)

        #expect(status.title == "Keeping your Mac awake")
        #expect(status.detail == "Until you turn it off")
    }

    @Test func timed() {
        let until = now.addingTimeInterval(6120)
        let status = MenuStatus(state: .active(until: until), now: now, timeFormatter: formatter)

        #expect(status.detail == "1h 42m remaining · until \(formatter.string(from: until))")
    }
}
