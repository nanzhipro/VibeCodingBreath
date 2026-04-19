import AppKit

@MainActor
final class AppCoordinator {
    enum State { case hidden, showing, dismissing }

    private let statusItem: StatusItemControlling
    private let idleMonitor: IdleProviding
    private let fgMonitor: ForegroundContextProviding
    private let overlay: OverlayControlling
    private let loginItem: LoginItemManager

    private(set) var state: State = .hidden
    private(set) var isIdle: Bool = false
    private(set) var isFullscreen: Bool = false
    private(set) var manualOverride: Bool = false

    init(statusItem: StatusItemControlling,
         idleMonitor: IdleProviding,
         fgMonitor: ForegroundContextProviding,
         overlay: OverlayControlling,
         loginItem: LoginItemManager = LoginItemManager()) {
        self.statusItem = statusItem
        self.idleMonitor = idleMonitor
        self.fgMonitor = fgMonitor
        self.overlay = overlay
        self.loginItem = loginItem
    }

    static func makeDefault() -> AppCoordinator {
        let engine = BreathingEngine()
        return AppCoordinator(
            statusItem: StatusItemController(),
            idleMonitor: IdleMonitor(),
            fgMonitor: ForegroundContextMonitor(),
            overlay: OverlayWindowController(engine: engine)
        )
    }

    func start() {
        loginItem.registerIfNeeded()
        statusItem.install()
        statusItem.onOpen = { [weak self] in self?.openManually() }
        statusItem.onQuit = { NSApp.terminate(nil) }

        idleMonitor.onChange = { [weak self] idle in
            self?.handleIdle(idle)
        }
        fgMonitor.onChange = { [weak self] fs in
            self?.handleFullscreen(fs)
        }

        idleMonitor.start()
        fgMonitor.start()

        isIdle = idleMonitor.isIdle
        isFullscreen = fgMonitor.isFullscreenContext
        evaluate()
    }

    func stop() {
        idleMonitor.stop()
        fgMonitor.stop()
        overlay.cleanup()
        statusItem.uninstall()
    }

    func openManually() {
        guard !isFullscreen else {
            AppLogger.app.info("Manual open ignored: fullscreen context.")
            return
        }
        manualOverride = true
        evaluate()
    }

    func handleSleep() {
        if state == .showing {
            overlay.hide()
            state = .hidden
        }
    }

    func handleWake() {
        evaluate()
    }

    func handleIdle(_ idle: Bool) {
        isIdle = idle
        if !idle {
            manualOverride = false
        }
        evaluate()
    }

    func handleFullscreen(_ fs: Bool) {
        isFullscreen = fs
        evaluate()
    }

    func shouldShow() -> Bool {
        if isFullscreen { return false }
        return isIdle || manualOverride
    }

    func evaluate() {
        if shouldShow() {
            if state != .showing {
                overlay.show()
                state = .showing
            }
        } else {
            if state == .showing {
                state = .dismissing
                overlay.hide()
                state = .hidden
            }
        }
    }
}
