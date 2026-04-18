import XCTest

@testable import VibeCodingBreath

final class BreathPhaseTests: XCTestCase {
  func testPhaseDurationsMatchPRD() {
    XCTAssertEqual(BreathPhase.inhale.duration, 4.0)
    XCTAssertEqual(BreathPhase.holdAfterInhale.duration, 2.0)
    XCTAssertEqual(BreathPhase.exhale.duration, 6.0)
    XCTAssertEqual(BreathPhase.holdAfterExhale.duration, 2.0)
  }

  func testTargetScaleBounds() {
    for phase in BreathPhase.allCases {
      XCTAssertGreaterThanOrEqual(phase.targetScale, 1.0)
      XCTAssertLessThanOrEqual(phase.targetScale, 2.0)
    }
    XCTAssertEqual(BreathPhase.inhale.targetScale, 2.0)
    XCTAssertEqual(BreathPhase.exhale.targetScale, 1.0)
  }

  func testNextWrapsAround() {
    XCTAssertEqual(BreathPhase.inhale.next, .holdAfterInhale)
    XCTAssertEqual(BreathPhase.holdAfterInhale.next, .exhale)
    XCTAssertEqual(BreathPhase.exhale.next, .holdAfterExhale)
    XCTAssertEqual(BreathPhase.holdAfterExhale.next, .inhale)
  }
}
