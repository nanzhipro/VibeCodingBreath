import XCTest
@testable import VibeCodingBreath

final class BreathingEngineTests: XCTestCase {
    @MainActor
    func testInitialState() {
        let engine = BreathingEngine()
        XCTAssertEqual(engine.phase, .exhale)
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.taskSpawnCount, 0)
    }

    @MainActor
    func testStartEntersInhaleFirst() async throws {
        let engine = BreathingEngine()
        engine.start()
        XCTAssertTrue(engine.isRunning)
        // Allow the task to run its first iteration.
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(engine.phase, .inhale)
        engine.stop()
    }

    @MainActor
    func testStartIsIdempotent() async throws {
        let engine = BreathingEngine()
        engine.start()
        engine.start()
        engine.start()
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(engine.taskSpawnCount, 1)
        engine.stop()
    }

    @MainActor
    func testStopHaltsPhaseChanges() async throws {
        let engine = BreathingEngine()
        engine.start()
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(engine.phase, .inhale)
        engine.stop()
        XCTAssertFalse(engine.isRunning)
        let phaseAfterStop = engine.phase
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(engine.phase, phaseAfterStop)
    }

    @MainActor
    func testRestartAfterStop() async throws {
        let engine = BreathingEngine()
        engine.start()
        try await Task.sleep(for: .milliseconds(20))
        engine.stop()
        XCTAssertEqual(engine.taskSpawnCount, 1)
        engine.start()
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(engine.taskSpawnCount, 2)
        engine.stop()
    }
}
