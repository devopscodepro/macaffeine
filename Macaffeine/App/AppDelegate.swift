import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var awakeManager: AwakeManager?
    private var menuBarController: MenuBarController?
    private var settingsWindow: SettingsWindowController?
    private var hotKey: GlobalHotKey?
    private var safetyGuard: SafetyGuard?
    private var notifier: Notifier?
    // URLs that launched the app arrive before it's set up
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // unit tests use the app as a host, keep the menu bar clean there
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let settings = SettingsStore()
        let manager = AwakeManager(
            assertion: IOPMPowerAssertionManager(),
            scheduler: ExpirationTimer(),
            makeHoldScheduler: { ExpirationTimer() },
            processWatcher: ProcessWatcher(),
            duration: settings.duration,
            keepDisplayOn: settings.keepDisplayOn
        )
        let notifier = Notifier()
        self.notifier = notifier
        let settingsWindow = SettingsWindowController(settings: settings, notifier: notifier)
        manager.onAutoStop = { reason in
            if settings.notifyOnAutoStop { notifier.post(for: reason) }
        }
        safetyGuard = SafetyGuard(manager: manager, settings: settings, monitor: PowerMonitor())

        awakeManager = manager
        self.settingsWindow = settingsWindow
        menuBarController = MenuBarController(manager: manager, settings: settings) {
            settingsWindow.show()
        }
        hotKey = GlobalHotKey(keyCode: kVK_ANSI_K, modifiers: controlKey | optionKey | cmdKey) {
            manager.toggle()
        }
        installMainMenu()

        handle(pendingURLs)
        pendingURLs = []
    }

    func applicationWillTerminate(_ notification: Notification) {
        awakeManager?.deactivate()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard awakeManager != nil else {
            pendingURLs += urls
            return
        }
        handle(urls)
    }

    private func handle(_ urls: [URL]) {
        guard let manager = awakeManager else { return }

        for url in urls {
            guard let command = AwakeCommand.parse(url, now: Date()) else {
                Log.awake.error("Unknown URL: \(url.absoluteString, privacy: .public)")
                continue
            }
            switch command {
            case .activate(nil): manager.activate()
            case .activate(.indefinite?): manager.activate(until: nil)
            case .activate(.date(let date)?): manager.activate(until: date)
            case .deactivate: manager.deactivate()
            case .toggle: manager.toggle()
            case .hold(let hold): manager.hold(hold)
            case .release(let id): manager.release(holdID: id)
            }
        }
    }

    // click on the Dock icon while settings are open
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow?.show()
        return false
    }

    // only shown while the settings window is open
    private func installMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "Quit Macaffeine"), action: #selector(NSApplication.terminate), keyEquivalent: "q")

        let windowMenu = NSMenu(title: String(localized: "Window"))
        windowMenu.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose), keyEquivalent: "w")

        let mainMenu = NSMenu()
        for submenu in [appMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        NSApplication.shared.mainMenu = mainMenu
        NSApplication.shared.windowsMenu = windowMenu
    }
}
