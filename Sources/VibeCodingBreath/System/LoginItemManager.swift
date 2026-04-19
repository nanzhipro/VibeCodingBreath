import Foundation
import ServiceManagement

final class LoginItemManager {
    func registerIfNeeded() {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            return
        }
        do {
            try service.register()
            AppLogger.login.info("Registered login item.")
        } catch {
            AppLogger.login.error("Login item registration failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
