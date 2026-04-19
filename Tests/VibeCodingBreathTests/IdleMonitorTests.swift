import XCTest
@testable import VibeCodingBreath

final class IdleMonitorTests: XCTestCase {
    @MainActor
    func testEdgeFiresOncePerTransition() {
        let src = FakeIdleSource()
        let monitor = IdleMonitor(source: src, threshold: 5.0, interval: 60.0)
        var events: [Bool] = []
        monitor.onChange = { events.append($0) }

        src.seconds = 1.0
        monitor.tick()
        XCTAssertEqual(events, [])
        XCTAssertFalse(monitor.isIdle)

        src.seconds = 6.0
        monitor.tick()
        XCTAssertEqual(events, [true])
        XCTAssertTrue(monitor.isIdle)

        src.seconds = 7.5
        monitor.tick()
        XCTAssertEqual(events, [true])

        src.seconds = 0.1
        monitor.tick()
        XCTAssertEqual(events, [true, false])
        XCTAssertFalse(monitor.isIdle)

        src.seconds = 0.5
        monitor.tick()
        XCTAssertEqual(events, [true, false])
    }

    @MainActor
    func testThresholdBoundary() {
        let src = FakeIdleSource()
        let monitor = IdleMonitor(source: src, threshold: 5.0, interval: 60.0)
        var events: [Bool] = []
        monitor.onChange = { events.append($0) }

        src.seconds = 4.999
        monitor.tick()
        XCTAssertEqual(events, [])

        src.seconds = 5.0
        monitor.tick()
        XCTAssertEqual(events, [true])
    }

    @MainActor
    func testStopStopsTimer() {
        let src = FakeIdleSource()
        let monitor = IdleMonitor(source: src, threshold: 5.0, interval: 0.05)
        monitor.start()
        monitor.stop()
        // if the timer were still live the fake source at default 0 would not
        // flip `isIdle`; this test mostly validates no crash and no state change
        XCTAssertFalse(monitor.isIdle)
    }
}
