import Foundation

enum AwakeState: Equatable {
    case inactive
    case active(until: Date?)
}

@MainActor
final class AwakeManager {
    private(set) var state: AwakeState = .inactive {
        didSet {
            if state != oldValue { onChange?(state) }
        }
    }
    private(set) var duration: AwakeDuration
    var onChange: ((AwakeState) -> Void)?

    private let assertion: PowerAssertionManaging
    private let scheduler: ExpirationScheduling
    private let now: () -> Date

    init(
        assertion: PowerAssertionManaging,
        scheduler: ExpirationScheduling,
        duration: AwakeDuration = .indefinite,
        now: @escaping () -> Date = Date.init
    ) {
        self.assertion = assertion
        self.scheduler = scheduler
        self.duration = duration
        self.now = now
    }

    var isActive: Bool {
        if case .active = state { true } else { false }
    }

    var remaining: TimeInterval? {
        guard case .active(let until?) = state else { return nil }
        return max(0, until.timeIntervalSince(now()))
    }

    func toggle() {
        isActive ? deactivate() : activate()
    }

    func activate() {
        guard !isActive else { return }

        do {
            try assertion.acquire()
        } catch {
            Log.awake.error("Could not keep the Mac awake: \(String(describing: error), privacy: .public)")
            return
        }
        startCountdown()
    }

    func select(_ duration: AwakeDuration) {
        self.duration = duration
        if isActive {
            startCountdown()
        } else {
            activate()
        }
    }

    func deactivate() {
        guard isActive else { return }

        scheduler.cancel()
        assertion.release()
        state = .inactive
    }

    private func startCountdown() {
        let until = duration.expiration(from: now())
        if let until {
            scheduler.schedule(at: until) { [weak self] in self?.expire() }
        } else {
            scheduler.cancel()
        }
        state = .active(until: until)
        Log.awake.info("Keep awake on, duration: \(self.duration.rawValue, privacy: .public)")
    }

    private func expire() {
        Log.awake.info("Duration expired")
        deactivate()
    }
}
