import AppKit

@MainActor
enum EndTimePicker {
    // returns the next moment matching the picked time, today or tomorrow
    static func run(initial: Date) -> Date? {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        picker.dateValue = initial
        picker.sizeToFit()

        let alert = NSAlert()
        alert.messageText = String(localized: "Keep awake until")
        alert.informativeText = String(localized: "If the time has already passed today, Macaffeine keeps your Mac awake until that time tomorrow.")
        alert.accessoryView = picker
        alert.addButton(withTitle: String(localized: "Keep Awake"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        if #available(macOS 14, *) {
            NSApplication.shared.activate()
        } else {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        alert.window.initialFirstResponder = picker
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let parts = Calendar.current.dateComponents([.hour, .minute], from: picker.dateValue)
        return Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: parts.hour, minute: parts.minute),
            matchingPolicy: .nextTime
        )
    }
}
