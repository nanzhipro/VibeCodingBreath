import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var sleepObservationTasks: [Task<Void, Never>] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard enforceSingleInstance() else {
            AppLogger.app.info("Duplicate instance detected; terminating.")
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)

        let c = AppCoordinator.makeDefault()
        coordinator = c
        c.start()
        observeSleep()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
        for t in sleepObservationTasks { t.cancel() }
        sleepObservationTasks.removeAll()
    }

    private func enforceSingleInstance() -> Bool {
        let me = ProcessInfo.processInfo.processIdentifier
        let others = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == Constants.bundleIdentifier && $0.processIdentifier != me
        }
        return others.isEmpty
    }

    private func observeSleep() {
        let nc = NSWorkspace.shared.notificationCenter

        let sleepTask = Task { @MainActor [weak self] in
            for await _ in nc.notifications(named: NSWorkspace.willSleepNotification) {
                if Task.isCancelled { return }
                self?.coordinator?.handleSleep()
            }
        }
        sleepObservationTasks.append(sleepTask)

        let wakeTask = Task { @MainActor [weak self] in
            for await _ in nc.notifications(named: NSWorkspace.didWakeNotification) {
                if Task.isCancelled { return }
                self?.coordinator?.handleWake()
            }
        }
        sleepObservationTasks.append(wakeTask)
    }
}
