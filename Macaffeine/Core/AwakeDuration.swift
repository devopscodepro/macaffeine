import Foundation

enum AwakeDuration: String, CaseIterable, Sendable {
    case indefinite
    case minutes30
    case hour1
    case hours2
    case hours4
    case hours8

    var interval: TimeInterval? {
        switch self {
        case .indefinite: nil
        case .minutes30: 30 * 60
        case .hour1: 60 * 60
        case .hours2: 2 * 60 * 60
        case .hours4: 4 * 60 * 60
        case .hours8: 8 * 60 * 60
        }
    }

    var title: String {
        switch self {
        case .indefinite: String(localized: "Indefinite")
        case .minutes30: String(localized: "30 minutes")
        case .hour1: String(localized: "1 hour")
        case .hours2: String(localized: "2 hours")
        case .hours4: String(localized: "4 hours")
        case .hours8: String(localized: "8 hours")
        }
    }

    func expiration(from start: Date) -> Date? {
        interval.map { start.addingTimeInterval($0) }
    }
}

enum RemainingTime {
    // rounds up so the menu never shows 0m while still active
    static func format(_ interval: TimeInterval) -> String {
        let minutes = max(1, Int((interval / 60).rounded(.up)))
        let hours = minutes / 60
        let rest = minutes % 60

        if hours == 0 {
            return "\(rest)m"
        }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}
