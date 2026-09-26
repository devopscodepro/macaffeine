import Foundation

struct MenuStatus: Equatable {
    let title: String
    let detail: String

    init(state: AwakeState, now: Date, timeFormatter: DateFormatter = MenuStatus.timeFormatter) {
        switch state {
        case .inactive:
            title = String(localized: "Your Mac can sleep")
            detail = String(localized: "Choose a duration or press ⌃⌥⌘K")
        case .active(nil):
            title = String(localized: "Keeping your Mac awake")
            detail = String(localized: "Until you turn it off")
        case .active(let until?):
            let remaining = RemainingTime.format(max(0, until.timeIntervalSince(now)))
            let time = timeFormatter.string(from: until)
            title = String(localized: "Keeping your Mac awake")
            detail = String(localized: "\(remaining) remaining · until \(time)")
        }
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
