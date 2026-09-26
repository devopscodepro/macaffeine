import IOKit.pwr_mgt

protocol PowerAssertionManaging: AnyObject {
    var isHeld: Bool { get }
    func acquire(keepDisplayOn: Bool) throws
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
    private var keepsDisplayOn = false

    var isHeld: Bool { assertionID != nil }

    deinit {
        release()
    }

    // the display assertion also blocks idle system sleep, so one assertion is always enough
    func acquire(keepDisplayOn: Bool) throws {
        if assertionID != nil, keepsDisplayOn == keepDisplayOn { return }

        let type = keepDisplayOn ? kIOPMAssertPreventUserIdleDisplaySleep : kIOPMAssertPreventUserIdleSystemSleep
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Macaffeine keeps the Mac awake" as CFString,
            &id
        )
        guard result == kIOReturnSuccess else {
            Log.power.error("Failed to create assertion: \(result)")
            throw PowerAssertionError(code: result)
        }

        // swap after the new one exists so there's no gap
        if let old = assertionID {
            IOPMAssertionRelease(old)
        }
        assertionID = id
        keepsDisplayOn = keepDisplayOn
        Log.power.info("Assertion acquired, display on: \(keepDisplayOn)")
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
