import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var awakeManager: AwakeManager?
    private var menuBarController: MenuBarController?
    private var settingsWindow: SettingsWindowController?
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
        let settingsWindow = SettingsWindowController(settings: settings)

        awakeManager = manager
        self.settingsWindow = settingsWindow
        menuBarController = MenuBarController(manager: manager, settings: settings) {
            settingsWindow.show()
        }
        hotKey = GlobalHotKey(keyCode: kVK_ANSI_K, modifiers: controlKey | optionKey | cmdKey) {
            manager.toggle()
        }
        installMainMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        awakeManager?.deactivate()
    }

    // never visible for a menu bar app, but gives the settings window ⌘W and ⌘Q
    private func installMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "Close Window"), action: #selector(NSWindow.performClose), keyEquivalent: "w")
        appMenu.addItem(withTitle: String(localized: "Quit Macaffeine"), action: #selector(NSApplication.terminate), keyEquivalent: "q")

        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appItem)
        NSApplication.shared.mainMenu = mainMenu
    }
}
