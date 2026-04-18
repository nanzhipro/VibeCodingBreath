import AppKit

/// Heuristic detector for "user is in a fullscreen / presentation context".
///
/// We avoid private API. Instead we combine:
/// 1. Active space change notifications.
/// 2. Frontmost app activation.
/// 3. Whether the main screen's `visibleFrame` matches `frame` (menubar hidden ⇒ likely full-screen).
@MainActor
final class ForegroundContextMonitor: ForegroundContextProviding {
  private(set) var isFullscreenContext: Bool = false
  var onChange: ((Bool) -> Void)?

  private var observers: [NSObjectProtocol] = []

  func start() {
    let center = NSWorkspace.shared.notificationCenter
    let names: [NSNotification.Name] = [
      NSWorkspace.activeSpaceDidChangeNotification,
      NSWorkspace.didActivateApplicationNotification,
      NSWorkspace.didHideApplicationNotification,
      NSWorkspace.didUnhideApplicationNotification,
    ]
    for name in names {
      let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.reevaluate() }
      }
      observers.append(token)
    }
    reevaluate()
  }

  func stop() {
    let center = NSWorkspace.shared.notificationCenter
    for token in observers { center.removeObserver(token) }
    observers.removeAll()
  }

  /// Public for tests / manual re-eval.
  func reevaluate() {
    let nowFullscreen = Self.detectFullscreen()
    if nowFullscreen != isFullscreenContext {
      isFullscreenContext = nowFullscreen
      Log.context.debug("fullscreen context -> \(nowFullscreen, privacy: .public)")
      onChange?(nowFullscreen)
    }
  }

  private static func detectFullscreen() -> Bool {
    guard let main = NSScreen.main else { return false }
    // Menu bar is hidden ⇒ visibleFrame.height ≈ frame.height.
    // Allow 2pt tolerance for rounding / external display oddities.
    let menuBarHidden = abs(main.frame.height - main.visibleFrame.height) < 2.0
    // Ensure the foreground app is a regular UI app (not Finder w/ no windows).
    let frontIsRegular = NSWorkspace.shared.frontmostApplication?.activationPolicy == .regular
    return menuBarHidden && frontIsRegular
  }
}
