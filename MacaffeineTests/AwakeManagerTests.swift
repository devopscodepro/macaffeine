import Foundation
import Testing
@testable import Macaffeine

@MainActor
struct AwakeManagerTests {
    let assertion = MockPowerAssertionManager()
    let scheduler = MockExpirationScheduler()
    let clock = TestClock()
    let processWatcher = MockProcessWatcher()
    let holdSchedulers = HoldSchedulers()

    func makeManager(duration: AwakeDuration = .indefinite, keepDisplayOn: Bool = false) -> AwakeManager {
        let clock = clock
        let holdSchedulers = holdSchedulers
        return AwakeManager(
            assertion: assertion,
            scheduler: scheduler,
            makeHoldScheduler: { holdSchedulers.make() },
            processWatcher: processWatcher,
            duration: duration,
            keepDisplayOn: keepDisplayOn,
            now: { clock.now }
        )
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
        var autoStops: [StopReason] = []
        manager.onAutoStop = { autoStops.append($0) }
        manager.activate()

        clock.advance(by: 1800)
        scheduler.fire()

        #expect(manager.state == .inactive)
        #expect(!assertion.isHeld)
        #expect(manager.stopReason == .expired(at: clock.now))
        #expect(autoStops == [.expired(at: clock.now)])
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

    @Test func failedAcquireStaysInactiveWithReason() {
        assertion.failOnAcquire = true
        let manager = makeManager(duration: .minutes(60))

        manager.activate()

        #expect(manager.state == .inactive)
        #expect(manager.stopReason == .assertionFailed)
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

    @Test func activatesWithDisplayPreference() {
        let manager = makeManager(keepDisplayOn: true)

        manager.activate()

        #expect(assertion.keepsDisplayOn)
    }

    @Test func switchingDisplayWhileActiveKeepsCountdown() {
        let manager = makeManager(duration: .minutes(60))
        manager.activate()
        let state = manager.state

        manager.keepDisplayOn = true

        #expect(assertion.keepsDisplayOn)
        #expect(assertion.acquireCount == 2)
        #expect(manager.state == state)
    }

    @Test func switchingDisplayWhileInactiveDoesNotAcquire() {
        let manager = makeManager()

        manager.keepDisplayOn = true

        #expect(assertion.acquireCount == 0)
    }

    @Test func safetyCheckBlocksActivation() {
        let manager = makeManager()
        manager.safetyCheck = { .lowBattery(threshold: 20) }

        manager.activate()

        #expect(!manager.isActive)
        #expect(assertion.acquireCount == 0)
        #expect(manager.stopReason == .lowBattery(threshold: 20))
    }

    @Test func stopWithReasonReleasesAndReports() {
        let manager = makeManager(duration: .minutes(60))
        var autoStops: [StopReason] = []
        manager.onAutoStop = { autoStops.append($0) }
        manager.activate()

        manager.stop(because: .overheating)

        #expect(!manager.isActive)
        #expect(!assertion.isHeld)
        #expect(scheduler.deadline == nil)
        #expect(manager.stopReason == .overheating)
        #expect(autoStops == [.overheating])
    }

    @Test func stopWhenInactiveIsIgnored() {
        let manager = makeManager()
        var autoStops: [StopReason] = []
        manager.onAutoStop = { autoStops.append($0) }

        manager.stop(because: .lowPowerMode)

        #expect(manager.stopReason == nil)
        #expect(autoStops.isEmpty)
    }

    @Test func manualActionsClearReason() {
        let manager = makeManager()
        manager.activate()
        manager.stop(because: .lowPowerMode)

        manager.activate()
        #expect(manager.stopReason == nil)

        manager.stop(because: .lowPowerMode)
        manager.deactivate()
        #expect(manager.stopReason == nil)
    }

    @Test func holdKeepsMacAwake() {
        let manager = makeManager()

        manager.hold(Hold(id: "build", label: "make"))

        #expect(manager.isActive)
        #expect(!manager.isSessionActive)
        #expect(assertion.isHeld)
        #expect(manager.holds.map(\.id) == ["build"])
    }

    @Test func releasingLastHoldReleasesAssertion() {
        let manager = makeManager()
        manager.hold(Hold(id: "a"))
        manager.hold(Hold(id: "b"))

        manager.release(holdID: "a")
        #expect(assertion.isHeld)

        manager.release(holdID: "b")
        #expect(!assertion.isHeld)
        #expect(!manager.isActive)
    }

    @Test func holdDoesNotEndManualSession() {
        let manager = makeManager()
        manager.activate()

        manager.hold(Hold(id: "run"))
        manager.release(holdID: "run")

        #expect(manager.isSessionActive)
        #expect(assertion.isHeld)
        #expect(assertion.acquireCount == 1)
    }

    @Test func sessionExpiryKeepsHolds() {
        let manager = makeManager(duration: .minutes(30))
        var autoStops: [StopReason] = []
        manager.onAutoStop = { autoStops.append($0) }
        manager.activate()
        manager.hold(Hold(id: "run"))

        scheduler.fire()

        #expect(!manager.isSessionActive)
        #expect(manager.isActive)
        #expect(assertion.isHeld)
        #expect(autoStops.isEmpty)
    }

    @Test func holdIsReleasedWhenProcessExits() {
        let manager = makeManager()
        manager.hold(Hold(id: "run", pid: 4242))

        processWatcher.exit(4242)

        #expect(manager.holds.isEmpty)
        #expect(!assertion.isHeld)
    }

    @Test func holdExpires() {
        let manager = makeManager()
        manager.hold(Hold(id: "claude", until: clock.now.addingTimeInterval(7200)))

        #expect(holdSchedulers.all.first?.deadline == clock.now.addingTimeInterval(7200))
        holdSchedulers.all.first?.fire()

        #expect(manager.holds.isEmpty)
        #expect(!assertion.isHeld)
    }

    @Test func replacingHoldCancelsOldWatcher() {
        let manager = makeManager()
        manager.hold(Hold(id: "run", pid: 1))

        manager.hold(Hold(id: "run", pid: 2))

        #expect(processWatcher.cancelled == [1])
        #expect(manager.holds.count == 1)
    }

    @Test func deactivateDropsHolds() {
        let manager = makeManager()
        manager.activate()
        manager.hold(Hold(id: "run", pid: 7))

        manager.deactivate()

        #expect(manager.holds.isEmpty)
        #expect(!assertion.isHeld)
        #expect(processWatcher.cancelled == [7])
    }

    @Test func toggleTurnsOffHolds() {
        let manager = makeManager()
        manager.hold(Hold(id: "run"))

        manager.toggle()

        #expect(!manager.isActive)
    }

    @Test func safetyStopDropsHolds() {
        let manager = makeManager()
        manager.hold(Hold(id: "run"))

        manager.stop(because: .overheating)

        #expect(manager.holds.isEmpty)
        #expect(manager.stopReason == .overheating)
    }

    @Test func safetyBlocksHold() {
        let manager = makeManager()
        manager.safetyCheck = { .lowPowerMode }

        manager.hold(Hold(id: "run"))

        #expect(manager.holds.isEmpty)
        #expect(manager.stopReason == .lowPowerMode)
    }

    @Test func activateUntilDate() {
        let manager = makeManager(duration: .minutes(30))
        let until = clock.now.addingTimeInterval(5 * 3600)

        manager.activate(until: until)

        #expect(manager.state == .active(until: until))
        #expect(scheduler.deadline == until)
        #expect(manager.duration == .minutes(30))
    }
}

@MainActor
final class HoldSchedulers {
    private(set) var all: [MockExpirationScheduler] = []

    func make() -> MockExpirationScheduler {
        let scheduler = MockExpirationScheduler()
        all.append(scheduler)
        return scheduler
    }
}
