import CoreGraphics
import Foundation

/// Real provider that reads inactivity from CoreGraphics. Available without Accessibility permission.
final class CGEventInactivityProvider: EventInactivityProvider {
  private let trackedTypes: [CGEventType] = [
    .mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    .leftMouseDragged, .rightMouseDragged, .scrollWheel,
    .keyDown, .flagsChanged,
  ]

  func secondsSinceLastUserEvent() -> TimeInterval {
    var minSeconds: TimeInterval = .infinity
    for type in trackedTypes {
      let value = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: type)
      if value < minSeconds { minSeconds = value }
    }
    return minSeconds
  }
}

/// Production scheduler driven by a DispatchSourceTimer on the main queue.
final class DispatchTickScheduler: TickScheduler {
  private var timer: DispatchSourceTimer?

  func start(interval: TimeInterval, _ tick: @escaping @MainActor () -> Void) {
    stop()
    let t = DispatchSource.makeTimerSource(queue: .main)
    t.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(50))
    t.setEventHandler {
      // We are on the main queue; promote to MainActor.
      MainActor.assumeIsolated {
        tick()
      }
    }
    t.resume()
    timer = t
  }

  func stop() {
    timer?.cancel()
    timer = nil
  }
}

/// Polls inactivity and fires a callback whenever the idle/active state flips.
@MainActor
final class IdleMonitor {
  private(set) var isIdle: Bool = false
  var onChange: ((Bool) -> Void)?

  private let provider: EventInactivityProvider
  private let scheduler: TickScheduler
  private let threshold: TimeInterval
  private let pollInterval: TimeInterval

  init(
    provider: EventInactivityProvider = CGEventInactivityProvider(),
    scheduler: TickScheduler = DispatchTickScheduler(),
    threshold: TimeInterval = Constants.idleThreshold,
    pollInterval: TimeInterval = Constants.pollInterval
  ) {
    self.provider = provider
    self.scheduler = scheduler
    self.threshold = threshold
    self.pollInterval = pollInterval
  }

  func start() {
    scheduler.start(interval: pollInterval) { [weak self] in
      self?.tick()
    }
  }

  func stop() {
    scheduler.stop()
  }

  /// Public for tests: evaluate one cycle.
  func tick() {
    let seconds = provider.secondsSinceLastUserEvent()
    let nowIdle = seconds >= threshold
    if nowIdle != isIdle {
      isIdle = nowIdle
      Log.idle.debug(
        "state changed -> \(nowIdle ? "idle" : "active") (\(seconds, privacy: .public)s)")
      onChange?(nowIdle)
    }
  }
}
