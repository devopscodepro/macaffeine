import Foundation
import Testing
@testable import Macaffeine

struct SleepBlockersTests {
    let names: [pid_t: String] = [10: "caffeinate", 20: "Safari", 30: "Macaffeine", 40: "backupd"]

    func parse(_ assertions: [pid_t: [[String: Any]]]) -> [SleepBlocker] {
        SleepBlockers.parse(
            assertions,
            excluding: 30,
            processName: { names[$0] },
            parentName: { $0 == 10 ? "claude" : nil }
        )
    }

    @Test func listsOtherProcessesWithReason() {
        let blockers = parse([
            10: [["AssertType": "PreventUserIdleSystemSleep", "AssertName": "caffeinate command-line tool"]],
            20: [["AssertType": "PreventUserIdleDisplaySleep", "AssertName": "Playing video"]],
        ])

        #expect(blockers == [
            SleepBlocker(pid: 10, process: "caffeinate", parent: "claude", reason: "caffeinate command-line tool"),
            SleepBlocker(pid: 20, process: "Safari", parent: nil, reason: "Playing video"),
        ])
    }

    @Test func skipsOwnProcess() {
        #expect(parse([30: [["AssertType": "PreventUserIdleSystemSleep"]]]).isEmpty)
    }

    @Test func skipsNonBlockingTypes() {
        #expect(parse([40: [["AssertType": "UserIsActive"], ["AssertType": "BackgroundTask"]]]).isEmpty)
    }

    @Test func skipsUnknownProcesses() {
        #expect(parse([99: [["AssertType": "PreventSystemSleep"]]]).isEmpty)
    }
}
