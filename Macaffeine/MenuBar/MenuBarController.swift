import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let manager: AwakeManager
    private let settings: SettingsStore

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem()
    private let statusLineItem = NSMenuItem()
    private let launchAtLoginItem = NSMenuItem()
    private let durationMenu = NSMenu()
    private var durationItems: [(AwakeDuration, NSMenuItem)] = []
    private var refreshTimer: Timer?
    private var durationSubscription: AnyCancellable?

    init(manager: AwakeManager, settings: SettingsStore) {
        self.manager = manager
        self.settings = settings
        super.init()

        buildMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.toolTip = "Macaffeine"

        manager.onChange = { [weak self] _ in self?.update() }
        durationSubscription = settings.$duration.sink { [weak manager] in manager?.duration = $0 }
        update()
    }

    private func buildMenu() {
        menu.autoenablesItems = false

        toggleItem.title = String(localized: "Keep Awake")
        toggleItem.target = self
        toggleItem.action = #selector(toggle)
        toggleItem.keyEquivalent = "k"
        toggleItem.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(toggleItem)

        statusLineItem.isEnabled = false
        menu.addItem(statusLineItem)

        menu.addItem(.separator())

        let durationItem = NSMenuItem(title: String(localized: "Active for Duration"), action: nil, keyEquivalent: "")
        durationMenu.autoenablesItems = false
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

        menu.addItem(.separator())

        launchAtLoginItem.title = String(localized: "Launch at Login")
        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        menu.addItem(launchAtLoginItem)

        let quitItem = NSMenuItem(title: String(localized: "Quit Macaffeine"), action: #selector(NSApplication.terminate), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    // presets can change in settings, so rebuild every time the menu opens
    private func rebuildDurationMenu() {
        durationMenu.removeAllItems()
        durationItems = []

        for duration in settings.durations {
            let item = NSMenuItem(title: duration.title, action: #selector(selectDuration), keyEquivalent: "")
            item.target = self
            item.representedObject = duration.storedMinutes
            durationMenu.addItem(item)
            durationItems.append((duration, item))

            if duration == .indefinite {
                durationMenu.addItem(.separator())
            }
        }
    }

    private func update() {
        let isActive = manager.isActive

        toggleItem.state = isActive ? .on : .off
        statusLineItem.title = statusText()

        for (duration, item) in durationItems {
            item.state = duration == manager.duration ? .on : .off
        }

        let symbol = isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        let label = isActive
            ? String(localized: "Macaffeine, keeping your Mac awake")
            : String(localized: "Macaffeine, off")
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    private func statusText() -> String {
        guard case .active(let until) = manager.state else {
            return String(localized: "Off")
        }
        guard until != nil, let remaining = manager.remaining else {
            return String(localized: "On — Indefinite")
        }
        return String(localized: "On — \(RemainingTime.format(remaining)) remaining")
    }

    @objc private func toggle() {
        manager.toggle()
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        let duration = AwakeDuration(storedMinutes: minutes)
        settings.duration = duration
        manager.select(duration)
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildDurationMenu()
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        update()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
