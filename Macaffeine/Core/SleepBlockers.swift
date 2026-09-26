import AppKit
import IOKit.pwr_mgt

struct SleepBlocker: Equatable {
    let pid: pid_t
    let process: String
    let parent: String?
    let reason: String
}

enum SleepBlockers {
    // assertion types that stop idle sleep; display ones count too because they imply it
    static let blockingTypes: Set<String> = [
        "PreventUserIdleSystemSleep",
        "PreventSystemSleep",
        "NoIdleSleepAssertion",
        "PreventUserIdleDisplaySleep",
        "NoDisplaySleepAssertion",
    ]

    static func current() -> [SleepBlocker] {
        var result: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&result) == kIOReturnSuccess,
              let map = result?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return [] }

        let byPid = Dictionary(uniqueKeysWithValues: map.map { ($0.key.int32Value, $0.value) })
        return parse(byPid, excluding: getpid(), processName: processName, parentName: parentName)
    }

    static func parse(
        _ assertions: [pid_t: [[String: Any]]],
        excluding ownPid: pid_t,
        processName: (pid_t) -> String?,
        parentName: (pid_t) -> String?
    ) -> [SleepBlocker] {
        var blockers: [SleepBlocker] = []
        for (pid, list) in assertions where pid != ownPid {
            let blocking = list.filter { blockingTypes.contains($0["AssertType"] as? String ?? "") }
            guard let first = blocking.first, let name = processName(pid) else { continue }
            blockers.append(SleepBlocker(
                pid: pid,
                process: name,
                parent: parentName(pid),
                reason: first["AssertName"] as? String ?? ""
            ))
        }
        return blockers.sorted { ($0.process.lowercased(), $0.pid) < ($1.process.lowercased(), $1.pid) }
    }

    private static func processName(_ pid: pid_t) -> String? {
        if let app = NSRunningApplication(processIdentifier: pid), let name = app.localizedName {
            return name
        }
        var buffer = [UInt8](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)), as: UTF8.self)
    }

    // command line tools like caffeinate are more useful with who started them
    private static func parentName(_ pid: pid_t) -> String? {
        guard NSRunningApplication(processIdentifier: pid) == nil else { return nil }

        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        let ppid = pid_t(info.pbi_ppid)
        guard ppid > 1 else { return nil }
        return processName(ppid)
    }
}
