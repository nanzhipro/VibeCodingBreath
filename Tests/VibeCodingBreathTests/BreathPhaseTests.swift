import XCTest
@testable import VibeCodingBreath

final class BreathPhaseTests: XCTestCase {
    func testCaseOrder() {
        XCTAssertEqual(
            BreathPhase.allCases,
            [.inhale, .holdAfterInhale, .exhale, .holdAfterExhale]
        )
    }

    func testDurations() {
        XCTAssertEqual(BreathPhase.inhale.duration, 4.0)
        XCTAssertEqual(BreathPhase.holdAfterInhale.duration, 2.0)
        XCTAssertEqual(BreathPhase.exhale.duration, 6.0)
        XCTAssertEqual(BreathPhase.holdAfterExhale.duration, 2.0)
        let total = BreathPhase.allCases.reduce(0.0) { $0 + $1.duration }
        XCTAssertEqual(total, 14.0)
    }

    func testTargetScales() {
        XCTAssertEqual(BreathPhase.inhale.targetScale, 2.0)
        XCTAssertEqual(BreathPhase.holdAfterInhale.targetScale, 2.0)
        XCTAssertEqual(BreathPhase.exhale.targetScale, 1.0)
        XCTAssertEqual(BreathPhase.holdAfterExhale.targetScale, 1.0)
    }

    func testLocalizationKeys() {
        XCTAssertEqual(BreathPhase.inhale.localizationKey, "phase.inhale")
        XCTAssertEqual(BreathPhase.holdAfterInhale.localizationKey, "phase.hold.afterInhale")
        XCTAssertEqual(BreathPhase.exhale.localizationKey, "phase.exhale")
        XCTAssertEqual(BreathPhase.holdAfterExhale.localizationKey, "phase.hold.afterExhale")
    }
}
