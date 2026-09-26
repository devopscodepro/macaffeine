import Foundation
import Testing
@testable import Macaffeine

struct AwakeDurationTests {
    let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func indefiniteHasNoExpiration() {
        #expect(AwakeDuration.indefinite.expiration(from: start) == nil)
    }

    @Test(arguments: [
        (AwakeDuration.minutes30, 30.0),
        (.hour1, 60),
        (.hours2, 120),
        (.hours4, 240),
        (.hours8, 480),
    ])
    func expirationAddsDuration(duration: AwakeDuration, minutes: Double) {
        #expect(duration.expiration(from: start) == start.addingTimeInterval(minutes * 60))
    }

    @Test func rawValuesAreStable() {
        #expect(AwakeDuration.allCases.map(\.rawValue) == [
            "indefinite", "minutes30", "hour1", "hours2", "hours4", "hours8",
        ])
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
