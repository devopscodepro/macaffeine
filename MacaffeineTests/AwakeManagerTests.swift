import Foundation
import Testing
@testable import Macaffeine

@MainActor
struct AwakeManagerTests {
    let assertion = MockPowerAssertionManager()
    let scheduler = MockExpirationScheduler()
    let clock = TestClock()

    func makeManager(duration: AwakeDuration = .indefinite) -> AwakeManager {
        let clock = clock
        return AwakeManager(assertion: assertion, scheduler: scheduler, duration: duration, now: { clock.now })
    }

    @Test func startsInactive() {
        let manager = makeManager()

        #expect(manager.state == .inactive)
        #expect(!manager.isActive)
        #expect(!assertion.isHeld)
    }

    @Test func activateIndefinitely() {
        let manager = makeManager()

        manager.activate()

        #expect(manager.state == .active(until: nil))
        #expect(assertion.isHeld)
        #expect(scheduler.deadline == nil)
        #expect(manager.remaining == nil)
    }

    @Test func activateWithDurationSchedulesExpiration() {
        let manager = makeManager(duration: .minutes(60))

        manager.activate()

        let until = clock.now.addingTimeInterval(3600)
        #expect(manager.state == .active(until: until))
        #expect(scheduler.deadline == until)
        #expect(assertion.isHeld)
    }

    @Test func deactivateReleasesAndCancels() {
        let manager = makeManager(duration: .minutes(60))
        manager.activate()

        manager.deactivate()

        #expect(manager.state == .inactive)
        #expect(!assertion.isHeld)
        #expect(assertion.releaseCount == 1)
        #expect(scheduler.deadline == nil)
    }

    @Test func toggleSwitchesState() {
        let manager = makeManager()

        manager.toggle()
        #expect(manager.isActive)

        manager.toggle()
        #expect(!manager.isActive)
        #expect(!assertion.isHeld)
    }

    @Test func activatingTwiceAcquiresOnce() {
        let manager = makeManager()

        manager.activate()
        manager.activate()

        #expect(assertion.acquireCount == 1)
    }

    @Test func deactivatingWhenInactiveDoesNothing() {
        let manager = makeManager()

        manager.deactivate()

        #expect(assertion.releaseCount == 0)
    }

    @Test func expirationTurnsItOff() {
        let manager = makeManager(duration: .minutes(30))
        manager.activate()

        clock.advance(by: 1800)
        scheduler.fire()

        #expect(manager.state == .inactive)
        #expect(!assertion.isHeld)
    }

    @Test func remainingCountsDown() throws {
        let manager = makeManager(duration: .minutes(120))
        manager.activate()

        clock.advance(by: 1080)

        let remaining = try #require(manager.remaining)
        #expect(abs(remaining - (7200 - 1080)) < 0.001)
    }

    @Test func selectingDurationWhileInactiveActivates() {
        let manager = makeManager()

        manager.select(.minutes(240))

        #expect(manager.duration == .minutes(240))
        #expect(manager.state == .active(until: clock.now.addingTimeInterval(4 * 3600)))
        #expect(assertion.isHeld)
    }

    @Test func selectingDurationWhileActiveRestartsFromNow() {
        let manager = makeManager(duration: .minutes(60))
        manager.activate()
        clock.advance(by: 600)

        manager.select(.minutes(120))

        let until = clock.now.addingTimeInterval(7200)
        #expect(manager.state == .active(until: until))
        #expect(scheduler.deadline == until)
        #expect(assertion.acquireCount == 1)
    }

    @Test func selectingIndefiniteWhileActiveDropsExpiration() {
        let manager = makeManager(duration: .minutes(60))
        manager.activate()

        manager.select(.indefinite)

        #expect(manager.state == .active(until: nil))
        #expect(scheduler.deadline == nil)
        #expect(assertion.isHeld)
    }

    @Test func failedAcquireStaysInactive() {
        assertion.failOnAcquire = true
        let manager = makeManager(duration: .minutes(60))

        manager.activate()

        #expect(manager.state == .inactive)
        #expect(scheduler.deadline == nil)
    }

    @Test func notifiesOnStateChange() {
        let manager = makeManager(duration: .minutes(60))
        var states: [AwakeState] = []
        manager.onChange = { states.append($0) }

        manager.activate()
        manager.deactivate()

        #expect(states == [.active(until: clock.now.addingTimeInterval(3600)), .inactive])
    }
}
