import Foundation

enum AwakeDuration: Hashable, Sendable {
    case indefinite
    case minutes(Int)

    static let defaultPresets = [5, 10, 15, 30, 60, 120, 180, 240, 300]
    static let maxMinutes = 24 * 60

    // 0 is what we store for indefinite
    init(storedMinutes: Int) {
        self = storedMinutes > 0 ? .minutes(storedMinutes) : .indefinite
    }

    var storedMinutes: Int {
        if case .minutes(let minutes) = self { minutes } else { 0 }
    }

    var interval: TimeInterval? {
        if case .minutes(let minutes) = self { TimeInterval(minutes * 60) } else { nil }
    }

    var title: String {
        switch self {
        case .indefinite: String(localized: "Indefinite")
        case .minutes(let minutes): DurationTitle.format(minutes: minutes)
        }
    }

    func expiration(from start: Date) -> Date? {
        interval.map { start.addingTimeInterval($0) }
    }
}

enum DurationTitle {
    // follow the app's UI language, not the system region, so the menu isn't mixed
    static func format(minutes: Int, locale: Locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")) -> String {
        var calendar = Calendar.current
        calendar.locale = locale

        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes) min"
    }
}

enum RemainingTime {
    // rounds up so the menu never shows 0m while still active
    static func format(_ interval: TimeInterval) -> String {
        let minutes = max(1, Int((interval / 60).rounded(.up)))
        let hours = minutes / 60
        let rest = minutes % 60

        if hours == 0 {
            return String(localized: "\(rest)m", comment: "Compact remaining time, minutes only")
        }
        return rest == 0
            ? String(localized: "\(hours)h", comment: "Compact remaining time, whole hours")
            : String(localized: "\(hours)h \(rest)m", comment: "Compact remaining time, hours and minutes")
    }
}
