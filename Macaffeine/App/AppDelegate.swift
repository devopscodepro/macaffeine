import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var awakeManager: AwakeManager?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // unit tests use the app as a host, keep the menu bar clean there
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let settings = SettingsStore()
        let manager = AwakeManager(
            assertion: IOPMPowerAssertionManager(),
            scheduler: ExpirationTimer(),
            duration: settings.duration
        )
        awakeManager = manager
        menuBarController = MenuBarController(manager: manager, settings: settings)
    }

    func applicationWillTerminate(_ notification: Notification) {
        awakeManager?.deactivate()
    }
}
