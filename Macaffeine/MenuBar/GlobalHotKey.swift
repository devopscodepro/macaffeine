import Carbon.HIToolbox

@MainActor
final class GlobalHotKey {
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    // Carbon is the only way to get a system-wide hotkey without Accessibility permission
    init(action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { hotKey.action() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        if status != noErr {
            Log.hotKey.error("InstallEventHandler failed: \(status)")
        }
    }

    // false when macOS refuses the combination; another app using it too is not reported
    @discardableResult
    func register(_ combo: HotKeyCombo?) -> Bool {
        unregister()
        guard let combo else { return true }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D434146), id: 1) // 'MCAF'
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode),
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            Log.hotKey.error("RegisterEventHotKey failed: \(status)")
            hotKeyRef = nil
            return false
        }
        Log.hotKey.debug("Hotkey registered")
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
    }
}
