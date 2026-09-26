import AppKit

@MainActor
protocol ExpirationScheduling: AnyObject {
    func schedule(at date: Date, handler: @escaping @MainActor () -> Void)
    func cancel()
}

@MainActor
final class ExpirationTimer: ExpirationScheduling {
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var deadline: Date?
    private var handler: (@MainActor () -> Void)?

    func schedule(at date: Date, handler: @escaping @MainActor () -> Void) {
        cancel()
        deadline = date
        self.handler = handler

        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // timers don't tick while the Mac sleeps, so recheck the deadline on wake
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.fireIfDue() }
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = nil
        deadline = nil
        handler = nil
    }

    private func fireIfDue() {
        guard let deadline, Date() >= deadline else { return }
        fire()
    }

    private func fire() {
        let handler = handler
        cancel()
        handler?()
    }
}
