import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let manager: AwakeManager
    private let settings: SettingsStore
    private let openSettings: () -> Void

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem()
    private let headerView = StatusHeaderView()
    private let headerItem = NSMenuItem()
    private let durationMenu = NSMenu()
    private let displayItem = NSMenuItem()
    private var durationItems: [(AwakeDuration, NSMenuItem)] = []
    private var refreshTimer: Timer?
    private var subscriptions: Set<AnyCancellable> = []

    init(manager: AwakeManager, settings: SettingsStore, openSettings: @escaping () -> Void) {
        self.manager = manager
        self.settings = settings
        self.openSettings = openSettings
        super.init()

        buildMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.toolTip = "Macaffeine"

        manager.onChange = { [weak self] _ in self?.update() }
        settings.$duration
            .sink { [weak manager] in manager?.duration = $0 }
            .store(in: &subscriptions)
        settings.$keepDisplayOn
            .sink { [weak manager] in manager?.keepDisplayOn = $0 }
            .store(in: &subscriptions)
        update()
    }

    private func buildMenu() {
        menu.autoenablesItems = false

        headerItem.view = headerView
        menu.addItem(headerItem)
        menu.addItem(.separator())

        toggleItem.title = String(localized: "Keep Awake")
        toggleItem.target = self
        toggleItem.action = #selector(toggle)
        toggleItem.keyEquivalent = "k"
        toggleItem.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(toggleItem)

        let durationItem = NSMenuItem(title: String(localized: "Active for Duration"), action: nil, keyEquivalent: "")
        durationMenu.autoenablesItems = false
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

        displayItem.title = String(localized: "Keep Display On")
        displayItem.target = self
        displayItem.action = #selector(toggleDisplay)
        menu.addItem(displayItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: String(localized: "Settings…"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

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
        let status = MenuStatus(state: manager.state, holds: manager.holds, stopReason: manager.stopReason, now: Date())
        headerView.configure(with: status)
        // not drawn because of the custom view, but VoiceOver reads it
        headerItem.title = "\(status.title). \(status.detail)"

        displayItem.state = settings.keepDisplayOn ? .on : .off

        for (duration, item) in durationItems {
            item.state = duration == manager.duration ? .on : .off
        }

        statusItem.button?.image = MenuBarIcon.image(isActive: isActive)
        statusItem.button?.setAccessibilityLabel(isActive
            ? String(localized: "Macaffeine, keeping your Mac awake")
            : String(localized: "Macaffeine, off"))
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

    @objc private func toggleDisplay() {
        settings.keepDisplayOn.toggle()
        update()
    }

    @objc private func showSettings() {
        openSettings()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildDurationMenu()
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
