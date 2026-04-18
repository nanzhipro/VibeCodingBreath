import XCTest

@testable import VibeCodingBreath

@MainActor
final class BreathingEngineTests: XCTestCase {
  func testStartBeginsAtInhale() async {
    let sleeper = ManualSleepProvider()
    let engine = BreathingEngine(sleeper: sleeper)
    engine.start()
    XCTAssertEqual(engine.phase, .inhale)
    XCTAssertTrue(engine.isRunning)
    engine.stop()
  }

  func testPhaseSequenceAdvances() async {
    let sleeper = ManualSleepProvider()
    let engine = BreathingEngine(sleeper: sleeper)
    engine.start()

    // Wait for the sleep to be registered, then advance.
    try? await waitForPending(in: sleeper)
    await sleeper.tick()
    try? await waitForPhase(.holdAfterInhale, on: engine)

    try? await waitForPending(in: sleeper)
    await sleeper.tick()
    try? await waitForPhase(.exhale, on: engine)

    try? await waitForPending(in: sleeper)
    await sleeper.tick()
    try? await waitForPhase(.holdAfterExhale, on: engine)

    try? await waitForPending(in: sleeper)
    await sleeper.tick()
    try? await waitForPhase(.inhale, on: engine)

    engine.stop()
  }

  func testStopCancelsLoop() async {
    let sleeper = ManualSleepProvider()
    let engine = BreathingEngine(sleeper: sleeper)
    engine.start()
    try? await waitForPending(in: sleeper)
    engine.stop()
    XCTAssertFalse(engine.isRunning)

    // Even if we tick, no further phase change.
    let priorPhase = engine.phase
    await sleeper.tick()
    try? await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(engine.phase, priorPhase)
  }

  func testStartIsIdempotent() async {
    let sleeper = ManualSleepProvider()
    let engine = BreathingEngine(sleeper: sleeper)
    engine.start()
    engine.start()
    try? await waitForPending(in: sleeper)
    let pending = await sleeper.pendingCount()
    XCTAssertEqual(pending, 1)
    engine.stop()
  }

  // MARK: helpers

  private func waitForPending(in sleeper: ManualSleepProvider, attempts: Int = 50) async throws {
    for _ in 0..<attempts {
      if await sleeper.pendingCount() > 0 { return }
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTFail("Timed out waiting for sleep registration")
  }

  private func waitForPhase(_ expected: BreathPhase, on engine: BreathingEngine, attempts: Int = 50)
    async throws
  {
    for _ in 0..<attempts {
      if engine.phase == expected { return }
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTFail("Timed out waiting for phase \(expected); current=\(engine.phase)")
  }
}
