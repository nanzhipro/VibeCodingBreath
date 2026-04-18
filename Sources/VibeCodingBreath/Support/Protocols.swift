import Foundation

/// Provides "seconds since the user last did anything" without requiring Accessibility permission.
protocol EventInactivityProvider: AnyObject, Sendable {
  func secondsSinceLastUserEvent() -> TimeInterval
}

/// Drives periodic ticks for the IdleMonitor; the real implementation uses DispatchSourceTimer,
/// tests use a manual scheduler that advances on demand.
protocol TickScheduler: AnyObject {
  func start(interval: TimeInterval, _ tick: @escaping @MainActor () -> Void)
  func stop()
}

/// Decides whether the foreground context (full-screen video, presentation, etc.) should suppress
/// the breathing overlay.
@MainActor
protocol ForegroundContextProviding: AnyObject {
  var isFullscreenContext: Bool { get }
  var onChange: ((Bool) -> Void)? { get set }
  func start()
  func stop()
}

/// Login-item registration abstraction so we can test without touching SMAppService.
protocol LoginItemControlling: AnyObject {
  var isEnabled: Bool { get }
  func enableIfNeeded()
  func disable()
}

/// Lets the coordinator drive the overlay without depending on AppKit in tests.
@MainActor
protocol OverlayPresenting: AnyObject {
  var isVisible: Bool { get }
  func show()
  func hide()
}
