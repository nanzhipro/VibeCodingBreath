import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var coordinator: AppCoordinator?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Make sure we behave as a menu-bar accessory even when launched as a bare executable
    // (Info.plist's LSUIElement still applies for the bundled .app build).
    NSApp.setActivationPolicy(.accessory)

    // Single-instance guard.
    let bundleID = Bundle.main.bundleIdentifier ?? Constants.bundleIdentifier
    let running = NSWorkspace.shared.runningApplications
      .filter {
        $0.bundleIdentifier == bundleID
          && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
      }
    if !running.isEmpty {
      Log.app.warning("another instance detected; terminating")
      NSApp.terminate(nil)
      return
    }

    let coordinator = AppCoordinator()
    coordinator.start()
    self.coordinator = coordinator
    Log.app.info("application did finish launching")
  }

  func applicationWillTerminate(_ notification: Notification) {
    coordinator?.stop()
    coordinator = nil
    Log.app.info("application will terminate")
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }
}
