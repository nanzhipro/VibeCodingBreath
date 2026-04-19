import Foundation
@testable import VibeCodingBreath

final class FakeIdleSource: IdleTimeSource {
    var seconds: TimeInterval = 0
    func secondsSinceLastEvent() -> TimeInterval { seconds }
}

@MainActor
final class FakeIdleMonitor: IdleProviding {
    var isIdle: Bool = false
    var onChange: ((Bool) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }

    func fire(_ idle: Bool) {
        isIdle = idle
        onChange?(idle)
    }
}

@MainActor
final class FakeForegroundMonitor: ForegroundContextProviding {
    var isFullscreenContext: Bool = false
    var onChange: ((Bool) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }

    func fire(_ fs: Bool) {
        isFullscreenContext = fs
        onChange?(fs)
    }
}

@MainActor
final class FakeOverlayController: OverlayControlling {
    private(set) var isShown: Bool = false
    private(set) var showCount = 0
    private(set) var hideCount = 0
    private(set) var cleanupCount = 0

    func show() { isShown = true; showCount += 1 }
    func hide() { isShown = false; hideCount += 1 }
    func cleanup() { isShown = false; cleanupCount += 1 }
}

@MainActor
final class FakeStatusItemController: StatusItemControlling {
    var onOpen: (() -> Void)?
    var onQuit: (() -> Void)?
    private(set) var installed = false
    private(set) var uninstalled = false

    func install() { installed = true }
    func uninstall() { uninstalled = true }
}
