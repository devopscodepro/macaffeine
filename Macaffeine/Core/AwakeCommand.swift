import Foundation

enum AwakeCommand: Equatable {
    case activate(until: ActivationEnd?)
    case deactivate
    case toggle
    case hold(Hold)
    case release(id: String)

    enum ActivationEnd: Equatable {
        case indefinite
        case date(Date)
    }

    static let maxMinutes = 7 * 24 * 60

    // macaffeine://activate?minutes=90, macaffeine://hold?id=build&pid=123 …
    static func parse(_ url: URL, now: Date, calendar: Calendar = .current) -> AwakeCommand? {
        guard url.scheme?.lowercased() == "macaffeine",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        let host = components.host ?? ""
        let action = (host.isEmpty ? components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) : host).lowercased()
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            query[item.name.lowercased()] = item.value
        }

        switch action {
        case "activate", "on":
            if query["duration"]?.lowercased() == "indefinite" {
                return .activate(until: .indefinite)
            }
            if let minutes = minutes(query["minutes"]) {
                return .activate(until: .date(now.addingTimeInterval(TimeInterval(minutes * 60))))
            }
            if let time = query["until"] {
                guard let date = nextOccurrence(of: time, after: now, calendar: calendar) else { return nil }
                return .activate(until: .date(date))
            }
            return .activate(until: nil)
        case "deactivate", "off":
            return .deactivate
        case "toggle":
            return .toggle
        case "hold":
            guard let id = identifier(query["id"]) else { return nil }
            let label = query["label"].map { String($0.prefix(60)) }.flatMap { $0.isEmpty ? nil : $0 }
            let pid = query["pid"].flatMap { Int32($0) }.flatMap { $0 > 0 ? $0 : nil }
            let until = minutes(query["minutes"]).map { now.addingTimeInterval(TimeInterval($0 * 60)) }
            return .hold(Hold(id: id, label: label, pid: pid, until: until))
        case "release":
            guard let id = identifier(query["id"]) else { return nil }
            return .release(id: id)
        default:
            return nil
        }
    }

    // "17:30" → today at 17:30, or tomorrow if that already passed
    static func nextOccurrence(of time: String, after now: Date, calendar: Calendar = .current) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }

        return calendar.nextDate(
            after: now,
            matching: DateComponents(hour: parts[0], minute: parts[1]),
            matchingPolicy: .nextTime
        )
    }

    private static func minutes(_ value: String?) -> Int? {
        guard let value, let minutes = Int(value), (1...maxMinutes).contains(minutes) else { return nil }
        return minutes
    }

    private static func identifier(_ value: String?) -> String? {
        guard let value, !value.isEmpty, value.count <= 100 else { return nil }
        return value
    }
}
