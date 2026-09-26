import Foundation
import Testing
@testable import Macaffeine

struct AwakeCommandTests {
    let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func parse(_ string: String) -> AwakeCommand? {
        AwakeCommand.parse(URL(string: string)!, now: now, calendar: calendar)
    }

    @Test func activateWithoutParamsUsesSelectedDuration() {
        #expect(parse("macaffeine://activate") == .activate(until: nil))
        #expect(parse("macaffeine:///on") == .activate(until: nil))
    }

    @Test func activateForMinutes() {
        #expect(parse("macaffeine://activate?minutes=90") == .activate(until: .date(now.addingTimeInterval(5400))))
    }

    @Test func activateIndefinitely() {
        #expect(parse("macaffeine://activate?duration=indefinite") == .activate(until: .indefinite))
    }

    @Test func activateUntilTime() throws {
        let command = try #require(parse("macaffeine://activate?until=17:30"))
        guard case .activate(.date(let date)?) = command else {
            Issue.record("unexpected \(command)")
            return
        }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        #expect(parts.hour == 17 && parts.minute == 30)
        #expect(date > now)
        #expect(date.timeIntervalSince(now) <= 24 * 3600)
    }

    @Test(arguments: ["macaffeine://activate?until=25:00", "macaffeine://activate?until=noon"])
    func badTimeIsRejected(url: String) {
        #expect(parse(url) == nil)
    }

    @Test func badMinutesFallBackToSelectedDuration() {
        #expect(parse("macaffeine://activate?minutes=0") == .activate(until: nil))
        #expect(parse("macaffeine://activate?minutes=abc") == .activate(until: nil))
    }

    @Test func simpleCommands() {
        #expect(parse("macaffeine://deactivate") == .deactivate)
        #expect(parse("macaffeine://off") == .deactivate)
        #expect(parse("macaffeine://toggle") == .toggle)
        #expect(parse("macaffeine://release?id=build") == .release(id: "build"))
    }

    @Test func hold() {
        let command = parse("macaffeine://hold?id=build&label=make%20test&pid=4242&minutes=60")

        #expect(command == .hold(Hold(id: "build", label: "make test", pid: 4242, until: now.addingTimeInterval(3600))))
    }

    @Test func holdIgnoresBadPid() {
        #expect(parse("macaffeine://hold?id=x&pid=-3") == .hold(Hold(id: "x")))
    }

    @Test func holdAndReleaseNeedID() {
        #expect(parse("macaffeine://hold") == nil)
        #expect(parse("macaffeine://release?id=") == nil)
    }

    @Test func rejectsUnknown() {
        #expect(parse("macaffeine://explode") == nil)
        #expect(parse("https://activate") == nil)
    }

    @Test func nextOccurrenceRollsOverToTomorrow() throws {
        let noon = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 12)))

        let later = AwakeCommand.nextOccurrence(of: "17:00", after: noon, calendar: calendar)
        let earlier = AwakeCommand.nextOccurrence(of: "09:00", after: noon, calendar: calendar)

        #expect(later == noon.addingTimeInterval(5 * 3600))
        #expect(earlier == noon.addingTimeInterval(21 * 3600))
    }
}
