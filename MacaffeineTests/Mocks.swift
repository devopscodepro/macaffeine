import Foundation
@testable import Macaffeine

final class MockPowerAssertionManager: PowerAssertionManaging {
    private(set) var isHeld = false
    private(set) var acquireCount = 0
    private(set) var releaseCount = 0
    var failOnAcquire = false

    func acquire() throws {
        if failOnAcquire { throw PowerAssertionError(code: -1) }
        acquireCount += 1
        isHeld = true
    }

    func release() {
        releaseCount += 1
        isHeld = false
    }
}

@MainActor
final class MockExpirationScheduler: ExpirationScheduling {
    private(set) var deadline: Date?
    private(set) var cancelCount = 0
    private var handler: (@MainActor () -> Void)?

    func schedule(at date: Date, handler: @escaping @MainActor () -> Void) {
        deadline = date
        self.handler = handler
    }

    func cancel() {
        cancelCount += 1
        deadline = nil
        handler = nil
    }

    func fire() {
        let handler = handler
        deadline = nil
        self.handler = nil
        handler?()
    }
}

final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
