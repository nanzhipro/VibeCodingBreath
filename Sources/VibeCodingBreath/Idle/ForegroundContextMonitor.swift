import AppKit

@MainActor
final class ForegroundContextMonitor: ForegroundContextProviding {
    private(set) var isFullscreenContext: Bool = false
    var onChange: ((Bool) -> Void)?
    private var observationTasks: [Task<Void, Never>] = []

    func start() {
        stop()
        let nc = NSWorkspace.shared.notificationCenter
        let names = [
            NSWorkspace.activeSpaceDidChangeNotification,
            NSWorkspace.didActivateApplicationNotification
        ]
        for name in names {
            let task = Task { @MainActor [weak self] in
                for await _ in nc.notifications(named: name) {
                    if Task.isCancelled { return }
                    self?.evaluate()
                }
            }
            observationTasks.append(task)
        }
        evaluate()
    }

    func stop() {
        for t in observationTasks { t.cancel() }
        observationTasks.removeAll()
    }

    func evaluate() {
        let fs = Self.detectFullscreen()
        guard fs != isFullscreenContext else { return }
        isFullscreenContext = fs
        AppLogger.app.debug("fullscreen context -> \(fs, privacy: .public)")
        onChange?(fs)
    }

    static func detectFullscreen() -> Bool {
        guard let screen = NSScreen.main else { return false }
        let visibleHeight = screen.visibleFrame.height
        let fullHeight = screen.frame.height
        let menuBarHidden = abs(fullHeight - visibleHeight) < 1.0
        let frontmost = NSWorkspace.shared.frontmostApplication
        let isRegular = frontmost?.activationPolicy == .regular
        return menuBarHidden && isRegular
    }
}
