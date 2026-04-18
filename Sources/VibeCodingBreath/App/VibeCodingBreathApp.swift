import SwiftUI

@main
struct VibeCodingBreathApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    // Empty Settings scene — keeps SwiftUI happy without ever creating a window.
    Settings {
      EmptyView()
    }
  }
}
