import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let manager: AwakeManager
    private let settings: SettingsStore
    private let openSettings: () -> Void

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem()
    private let headerView = StatusHeaderView()
    private let headerItem = NSMenuItem()
    private let durationMenu = NSMenu()
    private let displayItem = NSMenuItem()
    private var durationItems: [(AwakeDuration, NSMenuItem)] = []
    private let untilItem = NSMenuItem()
    private let blockersItem = NSMenuItem()
    private let blockersMenu = NSMenu()
    private var blockers: [SleepBlocker] = []
    private var refreshTimer: Timer?
    private var countdownTimer: Timer?
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
        settings.$showsCountdown
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.update() }
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
        menu.addItem(toggleItem)

        let durationItem = NSMenuItem(title: String(localized: "Active for Duration"), action: nil, keyEquivalent: "")
        durationMenu.autoenablesItems = false
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

        blockersItem.title = String(localized: "Also Keeping Your Mac Awake")
        blockersMenu.autoenablesItems = false
        blockersItem.submenu = blockersMenu
        blockersItem.isHidden = true
        menu.addItem(blockersItem)

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

        durationMenu.addItem(.separator())
        untilItem.target = self
        untilItem.action = #selector(chooseEndTime)
        durationMenu.addItem(untilItem)
    }

    private func update() {
        let isActive = manager.isActive

        toggleItem.state = isActive ? .on : .off
        toggleItem.keyEquivalent = settings.hotKey?.keyEquivalent ?? ""
        toggleItem.keyEquivalentModifierMask = settings.hotKey?.modifiers ?? []
        let status = MenuStatus(
            state: manager.state,
            holds: manager.holds,
            stopReason: manager.stopReason,
            othersKeepAwake: !blockers.isEmpty,
            shortcut: settings.hotKey?.displayString,
            now: Date()
        )
        headerView.configure(with: status)
        // not drawn because of the custom view, but VoiceOver reads it
        headerItem.title = "\(status.title). \(status.detail)"

        displayItem.state = settings.keepDisplayOn ? .on : .off

        let isCustom = manager.isSessionActive && manager.isCustomSession
        for (duration, item) in durationItems {
            item.state = !isCustom && duration == manager.duration ? .on : .off
        }
        untilItem.state = isCustom ? .on : .off
        if isCustom, case .active(let until?) = manager.state {
            untilItem.title = String(localized: "Until \(MenuStatus.timeFormatter.string(from: until))…")
        } else {
            untilItem.title = String(localized: "Until…")
        }

        statusItem.button?.image = MenuBarIcon.image(isActive: isActive)
        updateCountdown()
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

    private func updateCountdown() {
        guard let button = statusItem.button else { return }

        guard settings.showsCountdown, let remaining = manager.remaining else {
            button.title = ""
            button.imagePosition = .imageOnly
            statusItem.length = NSStatusItem.squareLength
            countdownTimer?.invalidate()
            countdownTimer = nil
            return
        }

        statusItem.length = NSStatusItem.variableLength
        button.title = RemainingTime.format(remaining)
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .regular)
        button.imagePosition = .imageLeading

        if countdownTimer == nil {
            let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateCountdown() }
            }
            timer.tolerance = 5
            RunLoop.main.add(timer, forMode: .common)
            countdownTimer = timer
        }
    }

    private func rebuildBlockersMenu() {
        blockers = SleepBlockers.current()
        blockersMenu.removeAllItems()
        blockersItem.isHidden = blockers.isEmpty

        for blocker in blockers {
            let item = NSMenuItem()
            let name = blocker.parent.map { "\(blocker.process) (\($0))" } ?? blocker.process
            let title = NSMutableAttributedString(string: name)
            if !blocker.reason.isEmpty {
                title.append(NSAttributedString(
                    string: "  \(blocker.reason)",
                    attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize)]
                ))
            }
            item.attributedTitle = title
            item.setAccessibilityLabel(blocker.reason.isEmpty ? name : "\(name), \(blocker.reason)")

            if let app = NSRunningApplication(processIdentifier: blocker.pid) {
                item.image = app.icon.map { icon in
                    icon.size = NSSize(width: 16, height: 16)
                    return icon
                }
                item.representedObject = blocker.pid
                item.target = self
                item.action = #selector(showBlockingApp)
            } else {
                item.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
            }
            blockersMenu.addItem(item)
        }
    }

    @objc private func showBlockingApp(_ sender: NSMenuItem) {
        guard let pid = sender.representedObject as? pid_t else { return }
        NSRunningApplication(processIdentifier: pid)?.activate(options: [])
    }

    @objc private func chooseEndTime() {
        guard let date = EndTimePicker.run(initial: suggestedEndTime()) else { return }
        manager.activate(until: date)
    }

    // an hour from now, rounded up to a quarter
    private func suggestedEndTime() -> Date {
        let calendar = Calendar.current
        let inAnHour = Date().addingTimeInterval(3600)
        let minute = calendar.component(.minute, from: inAnHour)
        let rounded = calendar.date(byAdding: .minute, value: (15 - minute % 15) % 15, to: inAnHour) ?? inAnHour
        return calendar.date(bySetting: .second, value: 0, of: rounded) ?? rounded
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
        rebuildBlockersMenu()
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
