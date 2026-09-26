import Carbon.HIToolbox

@MainActor
final class GlobalHotKey {
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    // Carbon is the only way to get a system-wide hotkey without Accessibility permission
    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
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
        guard handlerStatus == noErr else {
            Log.hotKey.error("InstallEventHandler failed: \(handlerStatus)")
            return nil
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D434146), id: 1) // 'MCAF'
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            Log.hotKey.error("RegisterEventHotKey failed: \(registerStatus)")
            RemoveEventHandler(handlerRef)
            return nil
        }
        Log.hotKey.debug("Hotkey registered")
    }
}
