import Combine
import Foundation

@MainActor
protocol ProcessWatching {
    func watch(_ pid: pid_t, onExit: @escaping @MainActor () -> Void) -> AnyCancellable
}

@MainActor
final class ProcessWatcher: ProcessWatching {
    func watch(_ pid: pid_t, onExit: @escaping @MainActor () -> Void) -> AnyCancellable {
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { onExit() }
        }
        source.resume()

        // the process may already be gone, EPERM from the sandbox still means it exists
        if kill(pid, 0) != 0, errno == ESRCH {
            DispatchQueue.main.async { onExit() }
        }
        return AnyCancellable { source.cancel() }
    }
}
