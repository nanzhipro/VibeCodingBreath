import Foundation
import Observation

/// Drives the breathing cycle. Phase transitions are observable so SwiftUI can animate scale changes.
///
/// Time is delegated to a `ContinuousClock`-compatible sleep helper so unit tests can swap in
/// a fake (see `SleepProvider`).
@MainActor
@Observable
final class BreathingEngine {
  private(set) var phase: BreathPhase = .exhale
  private(set) var isRunning: Bool = false

  private var task: Task<Void, Never>?
  private let sleeper: SleepProvider

  init(sleeper: SleepProvider = SystemSleepProvider()) {
    self.sleeper = sleeper
  }

  func start(initialPhase: BreathPhase = .inhale) {
    guard !isRunning else { return }
    isRunning = true
    phase = initialPhase
    let sleeper = self.sleeper
    task = Task { [weak self] in
      // Sleep for the initial phase first, then advance forever.
      while !Task.isCancelled {
        guard let current = await self?.phase else { return }
        try? await sleeper.sleep(for: current.duration)
        if Task.isCancelled { return }
        await self?.advance()
      }
    }
  }

  func stop() {
    task?.cancel()
    task = nil
    isRunning = false
  }

  private func advance() {
    phase = phase.next
  }
}

// MARK: - Sleep abstraction

/// Allows tests to drive time without real waiting.
protocol SleepProvider: Sendable {
  func sleep(for seconds: TimeInterval) async throws
}

struct SystemSleepProvider: SleepProvider {
  func sleep(for seconds: TimeInterval) async throws {
    let nanos = UInt64((seconds * 1_000_000_000).rounded())
    try await Task.sleep(nanoseconds: nanos)
  }
}
