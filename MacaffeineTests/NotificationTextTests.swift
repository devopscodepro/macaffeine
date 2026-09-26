import Foundation
import Testing
@testable import Macaffeine

struct NotificationTextTests {
    @Test func expiredUsesFriendlyText() {
        let text = StopReason.expired(at: Date()).notificationText

        #expect(text?.title == "Keep Awake finished")
        #expect(text?.body == "Your Mac can sleep normally again.")
    }

    @Test func safetyStopsExplainWhy() {
        #expect(StopReason.lowBattery(threshold: 15).notificationText?.body.contains("15%") == true)
        #expect(StopReason.lowPowerMode.notificationText != nil)
        #expect(StopReason.overheating.notificationText != nil)
    }

    @Test func failuresAreNotNotified() {
        #expect(StopReason.assertionFailed.notificationText == nil)
    }
}
