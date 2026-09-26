import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let settings: SettingsStore
    private let notifier: Notifier
    private var window: NSWindow?

    init(settings: SettingsStore, notifier: Notifier) {
        self.settings = settings
        self.notifier = notifier
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window

        // show up in the Dock and ⌘Tab while settings are open
        NSApplication.shared.setActivationPolicy(.regular)
        if #available(macOS 14, *) {
            NSApplication.shared.activate()
        } else {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        window.makeKeyAndOrderFront(nil)
        // activation is only a request since macOS 14, make sure the window is at least visible
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(tab(
            GeneralSettingsView(settings: settings, notifier: notifier),
            title: String(localized: "General"),
            symbol: "gearshape"
        ))
        tabs.addTabViewItem(tab(
            DurationsSettingsView(settings: settings),
            title: String(localized: "Durations"),
            symbol: "timer"
        ))
        tabs.addTabViewItem(tab(
            SafetySettingsView(settings: settings),
            title: String(localized: "Safety"),
            symbol: "bolt.shield"
        ))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    private func tab(_ view: some View, title: String, symbol: String) -> NSTabViewItem {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = .preferredContentSize
        controller.title = title

        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}
