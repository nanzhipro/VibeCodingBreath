import XCTest

@testable import VibeCodingBreath

@MainActor
final class AppCoordinatorTests: XCTestCase {

  private struct Harness {
    let coordinator: AppCoordinator
    let provider: FakeInactivityProvider
    let scheduler: ManualTickScheduler
    let context: FakeContextProvider
    let overlay: RecordingOverlay
    let login: InMemoryLoginItem
  }

  private func makeHarness() -> Harness {
    let provider = FakeInactivityProvider()
    let scheduler = ManualTickScheduler()
    let monitor = IdleMonitor(
      provider: provider, scheduler: scheduler,
      threshold: 5.0, pollInterval: 0.5)
    let context = FakeContextProvider()
    let overlay = RecordingOverlay()
    let login = InMemoryLoginItem()
    let coordinator = AppCoordinator(
      idleMonitor: monitor,
      contextMonitor: context,
      overlay: overlay,
      loginItem: login,
      installsStatusItem: false)
    return Harness(
      coordinator: coordinator,
      provider: provider, scheduler: scheduler,
      context: context, overlay: overlay, login: login)
  }

  func testStartRegistersLoginItemAndStartsMonitors() {
    let h = makeHarness()
    h.coordinator.start()
    XCTAssertEqual(h.login.enableCalls, 1)
    XCTAssertEqual(h.context.startCount, 1)
    h.coordinator.stop()
  }

  func testIdleAndNotFullscreenShowsOverlay() {
    let h = makeHarness()
    h.coordinator.start()
    h.provider.seconds = 6.0
    h.scheduler.fire()
    XCTAssertEqual(h.overlay.showCalls, 1)
    h.coordinator.stop()
  }

  func testFullscreenSuppressesOverlay() {
    let h = makeHarness()
    h.coordinator.start()
    h.context.setFullscreen(true)
    h.provider.seconds = 6.0
    h.scheduler.fire()
    XCTAssertEqual(h.overlay.showCalls, 0)
    h.coordinator.stop()
  }

  func testManualOpenForcesShowEvenWhenActive() {
    let h = makeHarness()
    h.coordinator.start()
    let prior = h.overlay.showCalls
    h.coordinator.openManually()
    XCTAssertEqual(h.overlay.showCalls, prior + 1)
    h.coordinator.stop()
  }

  func testManualOpenIsSuppressedByFullscreen() {
    let h = makeHarness()
    h.coordinator.start()
    h.context.setFullscreen(true)
    let prior = h.overlay.showCalls
    h.coordinator.openManually()
    XCTAssertEqual(h.overlay.showCalls, prior)
    h.coordinator.stop()
  }

  func testActivityClearsManualOverride() {
    let h = makeHarness()
    h.coordinator.start()
    h.coordinator.openManually()
    XCTAssertGreaterThanOrEqual(h.overlay.showCalls, 1)

    h.provider.seconds = 6.0
    h.scheduler.fire()
    h.provider.seconds = 0.1
    h.scheduler.fire()
    XCTAssertGreaterThanOrEqual(h.overlay.hideCalls, 1)
    h.coordinator.stop()
  }

  func testStopCleansUp() {
    let h = makeHarness()
    h.coordinator.start()
    h.coordinator.stop()
    XCTAssertEqual(h.context.stopCount, 1)
  }
}
