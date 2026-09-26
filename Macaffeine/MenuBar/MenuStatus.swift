import Foundation

struct MenuStatus: Equatable {
    enum Tone {
        case active
        case idle
        case warning
        case error
    }

    let tone: Tone
    let title: String
    let detail: String

    init(state: AwakeState, stopReason: StopReason?, now: Date, timeFormatter: DateFormatter = MenuStatus.timeFormatter) {
        switch (state, stopReason) {
        case (.active(nil), _):
            tone = .active
            title = String(localized: "Keeping your Mac awake")
            detail = String(localized: "Until you turn it off")
        case (.active(let until?), _):
            let remaining = RemainingTime.format(max(0, until.timeIntervalSince(now)))
            tone = .active
            title = String(localized: "Keeping your Mac awake")
            detail = String(localized: "\(remaining) remaining · until \(timeFormatter.string(from: until))")
        case (.inactive, .expired(let date)?):
            tone = .idle
            title = String(localized: "Your Mac can sleep")
            detail = String(localized: "Timer finished at \(timeFormatter.string(from: date))")
        case (.inactive, .lowBattery(let threshold)?):
            tone = .warning
            title = String(localized: "Stopped to save battery")
            detail = String(localized: "Battery is below \(threshold)%. Plug in to keep awake.")
        case (.inactive, .lowPowerMode?):
            tone = .warning
            title = String(localized: "Stopped by Low Power Mode")
            detail = String(localized: "Turn off Low Power Mode to keep awake.")
        case (.inactive, .overheating?):
            tone = .warning
            title = String(localized: "Stopped, your Mac is too hot")
            detail = String(localized: "Let it cool down and try again.")
        case (.inactive, .assertionFailed?):
            tone = .error
            title = String(localized: "Couldn't keep your Mac awake")
            detail = String(localized: "macOS refused the request. Try again.")
        case (.inactive, nil):
            tone = .idle
            title = String(localized: "Your Mac can sleep")
            detail = String(localized: "Choose a duration or press ⌃⌥⌘K")
        }
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
