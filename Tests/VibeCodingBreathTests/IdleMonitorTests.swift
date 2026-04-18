import XCTest

@testable import VibeCodingBreath

@MainActor
final class IdleMonitorTests: XCTestCase {
  func testCrossesThresholdToIdle() {
    let provider = FakeInactivityProvider()
    let scheduler = ManualTickScheduler()
    let monitor = IdleMonitor(
      provider: provider,
      scheduler: scheduler,
      threshold: 5.0,
      pollInterval: 0.5)
    var changes: [Bool] = []
    monitor.onChange = { changes.append($0) }
    monitor.start()

    provider.seconds = 1.0
    scheduler.fire()
    provider.seconds = 4.99
    scheduler.fire()
    provider.seconds = 5.0
    scheduler.fire()
    provider.seconds = 6.0
    scheduler.fire()  // already idle, no extra callback

    XCTAssertEqual(changes, [true])
    XCTAssertTrue(monitor.isIdle)
  }

  func testReturnsToActive() {
    let provider = FakeInactivityProvider()
    let scheduler = ManualTickScheduler()
    let monitor = IdleMonitor(
      provider: provider, scheduler: scheduler,
      threshold: 5.0, pollInterval: 0.5)
    var changes: [Bool] = []
    monitor.onChange = { changes.append($0) }
    monitor.start()

    provider.seconds = 5.5
    scheduler.fire()  // -> idle
    provider.seconds = 0.1
    scheduler.fire()  // -> active
    provider.seconds = 0.2
    scheduler.fire()  // still active

    XCTAssertEqual(changes, [true, false])
    XCTAssertFalse(monitor.isIdle)
  }

  func testStopHaltsCallbacks() {
    let provider = FakeInactivityProvider()
    let scheduler = ManualTickScheduler()
    let monitor = IdleMonitor(
      provider: provider, scheduler: scheduler,
      threshold: 5.0, pollInterval: 0.5)
    var changes: [Bool] = []
    monitor.onChange = { changes.append($0) }
    monitor.start()
    monitor.stop()

    provider.seconds = 6.0
    scheduler.fire()  // scheduler is stopped → no closure registered

    XCTAssertEqual(changes, [])
  }
}
