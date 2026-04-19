import XCTest
@testable import VibeCodingBreath

final class AppCoordinatorTests: XCTestCase {
    @MainActor
    private func makeCoordinator() -> (
        AppCoordinator,
        FakeStatusItemController,
        FakeIdleMonitor,
        FakeForegroundMonitor,
        FakeOverlayController
    ) {
        let status = FakeStatusItemController()
        let idle = FakeIdleMonitor()
        let fg = FakeForegroundMonitor()
        let overlay = FakeOverlayController()
        let coord = AppCoordinator(
            statusItem: status,
            idleMonitor: idle,
            fgMonitor: fg,
            overlay: overlay
        )
        return (coord, status, idle, fg, overlay)
    }

    @MainActor
    func testDefaultHiddenAtStart() {
        let (coord, _, _, _, overlay) = makeCoordinator()
        coord.start()
        XCTAssertFalse(overlay.isShown)
        coord.stop()
    }

    @MainActor
    func testIdleShowsOverlay() {
        let (coord, _, idle, _, overlay) = makeCoordinator()
        coord.start()
        idle.fire(true)
        XCTAssertTrue(overlay.isShown)
        idle.fire(false)
        XCTAssertFalse(overlay.isShown)
        coord.stop()
    }

    @MainActor
    func testFullscreenSuppressesIdle() {
        let (coord, _, idle, fg, overlay) = makeCoordinator()
        coord.start()
        fg.fire(true)
        idle.fire(true)
        XCTAssertFalse(overlay.isShown)
        fg.fire(false)
        XCTAssertTrue(overlay.isShown)
        coord.stop()
    }

    @MainActor
    func testFullscreenHidesAlreadyShownOverlay() {
        let (coord, _, idle, fg, overlay) = makeCoordinator()
        coord.start()
        idle.fire(true)
        XCTAssertTrue(overlay.isShown)
        fg.fire(true)
        XCTAssertFalse(overlay.isShown)
        coord.stop()
    }

    @MainActor
    func testManualOverrideShowsOverlayWhenActive() {
        let (coord, _, _, _, overlay) = makeCoordinator()
        coord.start()
        XCTAssertFalse(overlay.isShown)
        coord.openManually()
        XCTAssertTrue(overlay.isShown)
        coord.stop()
    }

    @MainActor
    func testManualOverrideBlockedInFullscreen() {
        let (coord, _, _, fg, overlay) = makeCoordinator()
        coord.start()
        fg.fire(true)
        coord.openManually()
        XCTAssertFalse(overlay.isShown)
        coord.stop()
    }

    @MainActor
    func testManualOverrideClearsOnActiveEdge() {
        let (coord, _, idle, _, overlay) = makeCoordinator()
        coord.start()
        coord.openManually()
        XCTAssertTrue(overlay.isShown)
        idle.fire(true)
        XCTAssertTrue(overlay.isShown)
        idle.fire(false)
        XCTAssertFalse(overlay.isShown)
        coord.stop()
    }

    @MainActor
    func testStartInstallsStatusItem() {
        let (coord, status, _, _, _) = makeCoordinator()
        coord.start()
        XCTAssertTrue(status.installed)
        coord.stop()
        XCTAssertTrue(status.uninstalled)
    }

    @MainActor
    func testTruthTable() {
        // Exhaustive: (idle, fullscreen, manualOverride) → expected isShown
        // Only (!fullscreen && (idle || manualOverride)) is shown.
        struct Row { let idle: Bool; let fs: Bool; let manual: Bool; let shown: Bool }
        let rows: [Row] = [
            .init(idle: false, fs: false, manual: false, shown: false),
            .init(idle: true,  fs: false, manual: false, shown: true),
            .init(idle: false, fs: false, manual: true,  shown: true),
            .init(idle: true,  fs: false, manual: true,  shown: true),
            .init(idle: false, fs: true,  manual: false, shown: false),
            .init(idle: true,  fs: true,  manual: false, shown: false),
            .init(idle: false, fs: true,  manual: true,  shown: false),
            .init(idle: true,  fs: true,  manual: true,  shown: false)
        ]

        for row in rows {
            let (coord, _, idle, fg, overlay) = makeCoordinator()
            coord.start()
            fg.fire(row.fs)
            idle.fire(row.idle)
            if row.manual { coord.openManually() }
            XCTAssertEqual(
                overlay.isShown, row.shown,
                "idle=\(row.idle) fs=\(row.fs) manual=\(row.manual)"
            )
            coord.stop()
        }
    }
}
