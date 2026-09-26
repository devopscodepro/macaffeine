import os

enum Log {
    private static let subsystem = "pro.devopscode.Macaffeine"

    static let power = Logger(subsystem: subsystem, category: "power")
    static let awake = Logger(subsystem: subsystem, category: "awake")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let hotKey = Logger(subsystem: subsystem, category: "hotkey")
}
