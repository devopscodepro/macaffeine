import IOKit.pwr_mgt

protocol PowerAssertionManaging: AnyObject {
    var isHeld: Bool { get }
    func acquire() throws
    func release()
}

struct PowerAssertionError: Error, CustomStringConvertible {
    let code: IOReturn

    var description: String {
        "IOPMAssertionCreateWithName failed with code \(code)"
    }
}

final class IOPMPowerAssertionManager: PowerAssertionManaging {
    private var assertionID: IOPMAssertionID?

    var isHeld: Bool { assertionID != nil }

    deinit {
        release()
    }

    // display is allowed to sleep, only idle system sleep is blocked
    func acquire() throws {
        guard assertionID == nil else { return }

        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Macaffeine keeps the Mac awake" as CFString,
            &id
        )
        guard result == kIOReturnSuccess else {
            Log.power.error("Failed to create assertion: \(result)")
            throw PowerAssertionError(code: result)
        }

        assertionID = id
        Log.power.info("Assertion acquired")
    }

    func release() {
        guard let id = assertionID else { return }

        let result = IOPMAssertionRelease(id)
        if result != kIOReturnSuccess {
            Log.power.error("Failed to release assertion: \(result)")
        }
        assertionID = nil
        Log.power.info("Assertion released")
    }
}
