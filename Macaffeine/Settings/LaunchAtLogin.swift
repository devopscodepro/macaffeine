import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            Log.settings.info("Launch at login \(enabled ? "enabled" : "disabled", privacy: .public)")
        } catch {
            Log.settings.error("Launch at login change failed: \(String(describing: error), privacy: .public)")
        }

        // user has to allow it in System Settings first
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
