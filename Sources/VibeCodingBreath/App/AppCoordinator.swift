import AppKit

/// Single source of truth that wires monitors → decision → overlay.
@MainActor
final class AppCoordinator {
  private let idleMonitor: IdleMonitor
  private let contextMonitor: ForegroundContextProviding
  private let overlay: OverlayPresenting
  private let loginItem: LoginItemControlling
  private let installsStatusItem: Bool

  private var statusItem: StatusItemController?
  private var manualOverride: Bool = false
  private var sleepObserver: NSObjectProtocol?

  init(
    idleMonitor: IdleMonitor = IdleMonitor(),
    contextMonitor: ForegroundContextProviding = ForegroundContextMonitor(),
    overlay: OverlayPresenting? = nil,
    loginItem: LoginItemControlling = LoginItemManager(),
    installsStatusItem: Bool = true
  ) {
    self.idleMonitor = idleMonitor
    self.contextMonitor = contextMonitor
    self.overlay = overlay ?? OverlayWindowController()
    self.loginItem = loginItem
    self.installsStatusItem = installsStatusItem
  }

  func start() {
    Log.app.info("coordinator start")
    loginItem.enableIfNeeded()

    if installsStatusItem {
      statusItem = StatusItemController(
        onOpen: { [weak self] in self?.openManually() },
        onQuit: { [weak self] in self?.requestQuit() }
      )
    }

    idleMonitor.onChange = { [weak self] isIdle in
      guard let self else { return }
      if !isIdle && self.manualOverride {
        self.manualOverride = false
        Log.app.debug("manual override cleared by activity")
      }
      self.evaluate()
    }
    idleMonitor.start()

    contextMonitor.onChange = { [weak self] _ in self?.evaluate() }
    contextMonitor.start()

    let center = NSWorkspace.shared.notificationCenter
    sleepObserver = center.addObserver(
      forName: NSWorkspace.willSleepNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.handleSleep() }
    }

    evaluate()
  }

  func stop() {
    Log.app.info("coordinator stop")
    idleMonitor.stop()
    contextMonitor.stop()
    overlay.hide()
    statusItem?.remove()
    statusItem = nil
    if let token = sleepObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(token)
    }
    sleepObserver = nil
  }

  func openManually() {
    manualOverride = true
    evaluate()
  }

  func requestQuit() {
    NSApp.terminate(nil)
  }

  func evaluate() {
    let idle = idleMonitor.isIdle
    let fullscreen = contextMonitor.isFullscreenContext

    let shouldShow = !fullscreen && (manualOverride || idle)
    Log.app.debug(
      "evaluate idle=\(idle, privacy: .public) fs=\(fullscreen, privacy: .public) override=\(self.manualOverride, privacy: .public) -> show=\(shouldShow, privacy: .public)"
    )

    if shouldShow {
      overlay.show()
    } else {
      overlay.hide()
    }
  }

  private func handleSleep() {
    Log.app.info("system sleeping; hiding overlay")
    manualOverride = false
    overlay.hide()
  }
}
