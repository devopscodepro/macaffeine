import Foundation

enum StopReason: Equatable {
    case expired(at: Date)
    case lowBattery(threshold: Int)
    case lowPowerMode
    case overheating
    case assertionFailed
}
