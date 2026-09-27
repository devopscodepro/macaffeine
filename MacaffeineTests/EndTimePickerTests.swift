import Foundation
import Testing
@testable import Macaffeine

struct EndTimePickerTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func date(_ hour: Int, _ minute: Int, _ second: Int = 0, day: Int = 27) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute, second: second))!
    }

    @Test func roundsUpToQuarterAndDropsSeconds() {
        #expect(EndTimePicker.suggestion(after: date(23, 18, 35), calendar: calendar) == date(0, 30, day: 28))
    }

    @Test func exactQuarterStays() {
        #expect(EndTimePicker.suggestion(after: date(10, 15), calendar: calendar) == date(11, 15))
    }

    @Test func secondsPastQuarterGoToNextQuarter() {
        #expect(EndTimePicker.suggestion(after: date(10, 15, 20), calendar: calendar) == date(11, 30))
    }

    @Test func roundsIntoNextHour() {
        #expect(EndTimePicker.suggestion(after: date(10, 52), calendar: calendar) == date(12, 0))
    }
}
