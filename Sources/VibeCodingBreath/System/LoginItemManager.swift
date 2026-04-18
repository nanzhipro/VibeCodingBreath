import Foundation
import ServiceManagement

/// Wraps SMAppService.mainApp so the rest of the app can register/disable login-item silently.
final class LoginItemManager: LoginItemControlling {
  private let service: SMAppService

  init(service: SMAppService = .mainApp) {
    self.service = service
  }

  var isEnabled: Bool { service.status == .enabled }

  func enableIfNeeded() {
    guard service.status != .enabled else { return }
    do {
      try service.register()
      Log.login.info("login item registered")
    } catch {
      Log.login.error("login item register failed: \(String(describing: error), privacy: .public)")
    }
  }

  func disable() {
    do {
      try service.unregister()
      Log.login.info("login item unregistered")
    } catch {
      Log.login.error(
        "login item unregister failed: \(String(describing: error), privacy: .public)")
    }
  }
}
