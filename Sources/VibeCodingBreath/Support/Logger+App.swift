import os

enum AppLogger {
    nonisolated(unsafe) static let subsystem: String = Constants.bundleIdentifier
    nonisolated(unsafe) static let app = Logger(subsystem: subsystem, category: "app")
    nonisolated(unsafe) static let idle = Logger(subsystem: subsystem, category: "idle")
    nonisolated(unsafe) static let overlay = Logger(subsystem: subsystem, category: "overlay")
    nonisolated(unsafe) static let status = Logger(subsystem: subsystem, category: "status")
    nonisolated(unsafe) static let login = Logger(subsystem: subsystem, category: "login")
}
