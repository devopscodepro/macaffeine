import Combine
import Foundation

enum AwakeState: Equatable {
    case inactive
    case active(until: Date?)
}

// a request from outside the menu: CLI, URL scheme, Shortcuts
struct Hold: Equatable {
    let id: String
    var label: String?
    var pid: pid_t?
    var until: Date?
}

@MainActor
final class AwakeManager {
    // the session started from the menu or hotkey
    private(set) var state: AwakeState = .inactive {
        didSet {
            if state != oldValue { onChange?(state) }
        }
    }
    private(set) var holds: [Hold] = [] {
        didSet {
            if holds != oldValue { onChange?(state) }
        }
    }
    // changing it directly only affects the next activation, use select() to restart the countdown
    var duration: AwakeDuration
    var keepDisplayOn: Bool {
        didSet {
            guard assertion.isHeld, keepDisplayOn != oldValue else { return }
            do {
                try assertion.acquire(keepDisplayOn: keepDisplayOn)
            } catch {
                Log.awake.error("Could not switch display mode: \(String(describing: error), privacy: .public)")
            }
        }
    }
    private(set) var stopReason: StopReason? {
        didSet {
            if stopReason != oldValue { onChange?(state) }
        }
    }
    var onChange: ((AwakeState) -> Void)?
    var onAutoStop: ((StopReason) -> Void)?
    var safetyCheck: () -> StopReason? = { nil }

    private let assertion: PowerAssertionManaging
    private let scheduler: ExpirationScheduling
    private let makeHoldScheduler: () -> ExpirationScheduling
    private let processWatcher: ProcessWatching
    private let now: () -> Date
    private var holdTimers: [String: ExpirationScheduling] = [:]
    private var holdWatchers: [String: AnyCancellable] = [:]

    init(
        assertion: PowerAssertionManaging,
        scheduler: ExpirationScheduling,
        makeHoldScheduler: @escaping () -> ExpirationScheduling,
        processWatcher: ProcessWatching,
        duration: AwakeDuration = .indefinite,
        keepDisplayOn: Bool = false,
        now: @escaping () -> Date = Date.init
    ) {
        self.assertion = assertion
        self.scheduler = scheduler
        self.makeHoldScheduler = makeHoldScheduler
        self.processWatcher = processWatcher
        self.duration = duration
        self.keepDisplayOn = keepDisplayOn
        self.now = now
    }

    var isActive: Bool {
        isSessionActive || !holds.isEmpty
    }

    var isSessionActive: Bool {
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
        guard !isSessionActive, acquireIfNeeded() else { return }
        startSession(until: duration.expiration(from: now()))
    }

    func activate(until date: Date?) {
        guard acquireIfNeeded() else { return }
        startSession(until: date)
    }

    func select(_ duration: AwakeDuration) {
        self.duration = duration
        if isSessionActive {
            startSession(until: duration.expiration(from: now()))
        } else {
            activate()
        }
    }

    func hold(_ hold: Hold) {
        guard acquireIfNeeded() else { return }

        dropHold(id: hold.id)
        holds.append(hold)

        if let until = hold.until {
            let timer = makeHoldScheduler()
            timer.schedule(at: until) { [weak self] in self?.release(holdID: hold.id) }
            holdTimers[hold.id] = timer
        }
        if let pid = hold.pid {
            holdWatchers[hold.id] = processWatcher.watch(pid) { [weak self] in
                Log.awake.info("Process \(pid) exited")
                self?.release(holdID: hold.id)
            }
        }
        Log.awake.info("Hold added: \(hold.id, privacy: .public)")
    }

    func release(holdID: String) {
        guard holds.contains(where: { $0.id == holdID }) else { return }

        dropHold(id: holdID)
        Log.awake.info("Hold released: \(holdID, privacy: .public)")
        releaseAssertionIfIdle()
    }

    // user asked to let the Mac sleep: drop everything, including holds
    func deactivate() {
        releaseAll()
        stopReason = nil
    }

    func stop(because reason: StopReason) {
        guard isActive else { return }

        releaseAll()
        stopReason = reason
        onAutoStop?(reason)
    }

    private func acquireIfNeeded() -> Bool {
        if let reason = safetyCheck() {
            stopReason = reason
            return false
        }
        if !assertion.isHeld {
            do {
                try assertion.acquire(keepDisplayOn: keepDisplayOn)
            } catch {
                Log.awake.error("Could not keep the Mac awake: \(String(describing: error), privacy: .public)")
                stopReason = .assertionFailed
                return false
            }
        }
        stopReason = nil
        return true
    }

    private func startSession(until: Date?) {
        if let until {
            scheduler.schedule(at: until) { [weak self] in self?.expire() }
        } else {
            scheduler.cancel()
        }
        state = .active(until: until)
        Log.awake.info("Keep awake on, until: \(until?.description ?? "turned off", privacy: .public)")
    }

    private func expire() {
        Log.awake.info("Duration expired")
        if holds.isEmpty {
            stop(because: .expired(at: now()))
        } else {
            scheduler.cancel()
            state = .inactive
        }
    }

    private func dropHold(id: String) {
        holdTimers.removeValue(forKey: id)?.cancel()
        holdWatchers.removeValue(forKey: id)?.cancel()
        holds.removeAll { $0.id == id }
    }

    private func releaseAll() {
        scheduler.cancel()
        for id in holds.map(\.id) {
            dropHold(id: id)
        }
        state = .inactive
        releaseAssertionIfIdle()
    }

    private func releaseAssertionIfIdle() {
        if !isActive, assertion.isHeld {
            assertion.release()
        }
    }
}
