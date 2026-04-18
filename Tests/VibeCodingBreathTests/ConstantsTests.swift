import XCTest

@testable import VibeCodingBreath

final class ConstantsTests: XCTestCase {
  func testIdleThresholdDefault() {
    XCTAssertEqual(Constants.idleThreshold, 5.0, accuracy: 0.0001)
  }

  func testPollIntervalDefault() {
    XCTAssertEqual(Constants.pollInterval, 0.5, accuracy: 0.0001)
  }

  func testBreathCycleSumsTo14Seconds() {
    let total = BreathPhase.allCases.reduce(0) { $0 + $1.duration }
    XCTAssertEqual(total, 14.0, accuracy: 0.0001)
  }

  func testOverlaySizing() {
    XCTAssertLessThan(Constants.minDiameter, Constants.maxDiameter)
    XCTAssertEqual(Constants.minDiameter, 120)
    XCTAssertEqual(Constants.maxDiameter, 320)
  }

  func testFadeTimings() {
    XCTAssertEqual(Constants.fadeIn, 0.4, accuracy: 0.0001)
    XCTAssertEqual(Constants.fadeOut, 0.2, accuracy: 0.0001)
    XCTAssertGreaterThan(Constants.fadeIn, Constants.fadeOut)
  }
}
