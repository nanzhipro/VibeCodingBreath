import Foundation

protocol IdleTimeSource {
    func secondsSinceLastEvent() -> TimeInterval
}

@MainActor
protocol IdleProviding: AnyObject {
    var isIdle: Bool { get }
    var onChange: ((Bool) -> Void)? { get set }
    func start()
    func stop()
}

@MainActor
protocol ForegroundContextProviding: AnyObject {
    var isFullscreenContext: Bool { get }
    var onChange: ((Bool) -> Void)? { get set }
    func start()
    func stop()
}

@MainActor
protocol OverlayControlling: AnyObject {
    func show()
    func hide()
    func cleanup()
}

@MainActor
protocol StatusItemControlling: AnyObject {
    var onOpen: (() -> Void)? { get set }
    var onQuit: (() -> Void)? { get set }
    func install()
    func uninstall()
}
