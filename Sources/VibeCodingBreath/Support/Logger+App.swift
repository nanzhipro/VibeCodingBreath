import Foundation
import os

/// Shared loggers, partitioned by category for filtering in Console.app.
enum Log {
  private static let subsystem = Constants.bundleIdentifier
  static var app: Logger { Logger(subsystem: subsystem, category: "app") }
  static var idle: Logger { Logger(subsystem: subsystem, category: "idle") }
  static var overlay: Logger { Logger(subsystem: subsystem, category: "overlay") }
  static var status: Logger { Logger(subsystem: subsystem, category: "status") }
  static var login: Logger { Logger(subsystem: subsystem, category: "login") }
  static var context: Logger { Logger(subsystem: subsystem, category: "context") }
}
