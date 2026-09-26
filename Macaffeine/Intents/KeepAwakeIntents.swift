import AppIntents
import AppKit

struct KeepAwakeIntent: AppIntent {
    static let title: LocalizedStringResource = "Keep Mac Awake"
    static let description = IntentDescription("Keeps your Mac awake for a number of minutes, or until you turn it off.")

    @Parameter(title: "Minutes", description: "Leave empty to keep your Mac awake until you turn it off.", inclusiveRange: (1, 10080))
    var minutes: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Keep Mac awake for \(\.$minutes) minutes")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let manager = try awakeManager()
        manager.activate(until: minutes.map { Date().addingTimeInterval(TimeInterval($0 * 60)) })
        try ensureActive(manager)
        return .result()
    }
}

struct AllowSleepIntent: AppIntent {
    static let title: LocalizedStringResource = "Allow Mac to Sleep"
    static let description = IntentDescription("Turns off Keep Awake, including requests from the command line.")

    @MainActor
    func perform() async throws -> some IntentResult {
        try awakeManager().deactivate()
        return .result()
    }
}

struct ToggleKeepAwakeIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Keep Awake"
    static let description = IntentDescription("Turns Keep Awake on with the selected duration, or off.")

    @MainActor
    func perform() async throws -> some IntentResult {
        try awakeManager().toggle()
        return .result()
    }
}

struct IsKeptAwakeIntent: AppIntent {
    static let title: LocalizedStringResource = "Is Mac Kept Awake"
    static let description = IntentDescription("Tells whether Macaffeine is keeping your Mac awake right now.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: try awakeManager().isActive)
    }
}

struct MacaffeineShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: KeepAwakeIntent(),
            phrases: ["Keep my Mac awake with \(.applicationName)", "Start \(.applicationName)"],
            shortTitle: "Keep Mac Awake",
            systemImageName: "cup.and.saucer.fill"
        )
        AppShortcut(
            intent: AllowSleepIntent(),
            phrases: ["Let my Mac sleep with \(.applicationName)", "Stop \(.applicationName)"],
            shortTitle: "Allow Mac to Sleep",
            systemImageName: "cup.and.saucer"
        )
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case notReady
    case blocked(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notReady: "Macaffeine isn't running yet. Try again in a moment."
        case .blocked(let reason): "\(reason)"
        }
    }
}

@MainActor
private func awakeManager() throws -> AwakeManager {
    guard let manager = (NSApplication.shared.delegate as? AppDelegate)?.awakeManager else {
        throw IntentError.notReady
    }
    return manager
}

// a safety rule or macOS can refuse, say why instead of failing silently
@MainActor
private func ensureActive(_ manager: AwakeManager) throws {
    guard !manager.isActive else { return }
    let status = MenuStatus(state: manager.state, holds: manager.holds, stopReason: manager.stopReason, now: Date())
    throw IntentError.blocked(status.title)
}
