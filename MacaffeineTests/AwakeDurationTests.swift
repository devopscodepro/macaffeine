import Foundation
import Testing
@testable import Macaffeine

struct AwakeDurationTests {
    let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func indefiniteHasNoExpiration() {
        #expect(AwakeDuration.indefinite.expiration(from: start) == nil)
    }

    @Test(arguments: [5, 30, 60, 300, 1440])
    func expirationAddsMinutes(minutes: Int) {
        let expected = start.addingTimeInterval(TimeInterval(minutes * 60))
        #expect(AwakeDuration.minutes(minutes).expiration(from: start) == expected)
    }

    @Test func storedMinutesRoundTrip() {
        #expect(AwakeDuration(storedMinutes: 0) == .indefinite)
        #expect(AwakeDuration(storedMinutes: -1) == .indefinite)
        #expect(AwakeDuration(storedMinutes: 90) == .minutes(90))
        #expect(AwakeDuration.indefinite.storedMinutes == 0)
        #expect(AwakeDuration.minutes(90).storedMinutes == 90)
    }

    @Test(arguments: [
        (5, "5 minutes"),
        (60, "1 hour"),
        (90, "1 hour, 30 minutes"),
        (300, "5 hours"),
    ])
    func formatsTitle(minutes: Int, expected: String) {
        #expect(DurationTitle.format(minutes: minutes, locale: Locale(identifier: "en")) == expected)
    }

    @Test(arguments: [
        (6120.0, "1h 42m"),
        (3600, "1h"),
        (3601, "1h 1m"),
        (1800, "30m"),
        (59, "1m"),
        (0, "1m"),
        (28_800, "8h"),
    ])
    func formatsRemainingTime(interval: TimeInterval, expected: String) {
        #expect(RemainingTime.format(interval) == expected)
    }
}
