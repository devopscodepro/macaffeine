import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var awakeManager: AwakeManager?
    private var menuBarController: MenuBarController?
    private var hotKey: GlobalHotKey?

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
        hotKey = GlobalHotKey(keyCode: kVK_ANSI_K, modifiers: controlKey | optionKey | cmdKey) {
            manager.toggle()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        awakeManager?.deactivate()
    }
}
