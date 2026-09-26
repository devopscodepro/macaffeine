import Foundation
import IOKit.ps

@MainActor
final class PowerMonitor {
    private(set) var conditions: PowerConditions
    var onChange: ((PowerConditions) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var observers: [NSObjectProtocol] = []

    init() {
        conditions = Self.read()

        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }

        for name in [Notification.Name.NSProcessInfoPowerStateDidChange, ProcessInfo.thermalStateDidChangeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
    }

    func refresh() {
        let latest = Self.read()
        guard latest != conditions else { return }
        conditions = latest
        onChange?(latest)
    }

    private static func read() -> PowerConditions {
        var conditions = PowerConditions()
        conditions.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        conditions.isOverheating = ProcessInfo.processInfo.thermalState == .critical

        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return conditions }

        let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        conditions.isOnBattery = providing == kIOPSBatteryPowerValue

        let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] ?? []
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let max = description[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            conditions.batteryLevel = current * 100 / max
        }
        return conditions
    }
}
