import Foundation

@testable import VibeCodingBreath

/// A controllable inactivity provider for IdleMonitor tests.
final class FakeInactivityProvider: EventInactivityProvider, @unchecked Sendable {
  private let lock = NSLock()
  private var _seconds: TimeInterval = 0
  var seconds: TimeInterval {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _seconds
    }
    set {
      lock.lock()
      _seconds = newValue
      lock.unlock()
    }
  }
  func secondsSinceLastUserEvent() -> TimeInterval { seconds }
}

/// Tick scheduler that does nothing automatically — tests call `fire()` to advance.
final class ManualTickScheduler: TickScheduler {
  private var tickClosure: (@MainActor () -> Void)?

  func start(interval: TimeInterval, _ tick: @escaping @MainActor () -> Void) {
    tickClosure = tick
  }

  func stop() {
    tickClosure = nil
  }

  @MainActor
  func fire() {
    tickClosure?()
  }
}

/// In-memory replacement for the SMAppService-based login item.
final class InMemoryLoginItem: LoginItemControlling {
  private(set) var isEnabled: Bool = false
  private(set) var enableCalls: Int = 0
  private(set) var disableCalls: Int = 0

  func enableIfNeeded() {
    enableCalls += 1
    isEnabled = true
  }

  func disable() {
    disableCalls += 1
    isEnabled = false
  }
}

/// Records show/hide calls for OverlayPresenting.
@MainActor
final class RecordingOverlay: OverlayPresenting {
  private(set) var isVisible: Bool = false
  private(set) var showCalls: Int = 0
  private(set) var hideCalls: Int = 0

  func show() {
    showCalls += 1
    isVisible = true
  }

  func hide() {
    hideCalls += 1
    isVisible = false
  }
}

/// Fake context provider with manual control.
@MainActor
final class FakeContextProvider: ForegroundContextProviding {
  private(set) var isFullscreenContext: Bool = false
  var onChange: ((Bool) -> Void)?
  private(set) var startCount = 0
  private(set) var stopCount = 0

  func start() { startCount += 1 }
  func stop() { stopCount += 1 }

  func setFullscreen(_ value: Bool) {
    let changed = isFullscreenContext != value
    isFullscreenContext = value
    if changed { onChange?(value) }
  }
}

/// Sleep provider that advances instantly when the test calls `tick()`.
actor ManualSleepProvider: SleepProvider {
  private var continuations: [(TimeInterval, CheckedContinuation<Void, Never>)] = []

  func sleep(for seconds: TimeInterval) async throws {
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
      continuations.append((seconds, cont))
    }
  }

  /// Resume the next pending sleep (FIFO).
  func tick() {
    guard !continuations.isEmpty else { return }
    let (_, cont) = continuations.removeFirst()
    cont.resume()
  }

  func pendingCount() -> Int { continuations.count }
}
