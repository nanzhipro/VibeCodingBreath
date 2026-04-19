import AppKit

@MainActor
final class StatusItemController: NSObject, StatusItemControlling {
    private var item: NSStatusItem?
    var onOpen: (() -> Void)?
    var onQuit: (() -> Void)?

    func install() {
        let i = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = i.button {
            let image = NSImage(systemSymbolName: "wind", accessibilityDescription: "VibeCodingBreath")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()

        let openTitle = NSLocalizedString(
            "status.menu.open",
            bundle: AppResources.bundle,
            comment: "Manually show the breathing halo"
        )
        let openItem = NSMenuItem(title: openTitle, action: #selector(handleOpen), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitTitle = NSLocalizedString(
            "status.menu.quit",
            bundle: AppResources.bundle,
            comment: "Quit VibeCodingBreath"
        )
        let quitItem = NSMenuItem(title: quitTitle, action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        i.menu = menu
        item = i
    }

    func uninstall() {
        if let i = item {
            NSStatusBar.system.removeStatusItem(i)
        }
        item = nil
    }

    @objc private func handleOpen() {
        onOpen?()
    }

    @objc private func handleQuit() {
        onQuit?()
    }
}
