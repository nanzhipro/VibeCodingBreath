import AppKit

/// Builds the menu-bar status item with the two-action menu specified by PRD §F-2.
@MainActor
final class StatusItemController {
  private let statusItem: NSStatusItem
  private let onOpen: () -> Void
  private let onQuit: () -> Void

  init(onOpen: @escaping () -> Void, onQuit: @escaping () -> Void) {
    self.onOpen = onOpen
    self.onQuit = onQuit
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    configureButton()
    statusItem.menu = buildMenu()
    Log.status.info("status item ready")
  }

  deinit {
    // statusItem retained by NSStatusBar; rely on remove() at app shutdown.
  }

  func remove() {
    NSStatusBar.system.removeStatusItem(statusItem)
  }

  private func configureButton() {
    guard let button = statusItem.button else { return }
    let image =
      NSImage(systemSymbolName: "wind", accessibilityDescription: Constants.appDisplayName)
      ?? NSImage(
        systemSymbolName: "circle.dotted", accessibilityDescription: Constants.appDisplayName)
    image?.isTemplate = true
    button.image = image
    button.toolTip = Constants.appDisplayName
  }

  private func buildMenu() -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false

    let openTitle = String(localized: "status.menu.open", bundle: .module)
    let openItem = NSMenuItem(
      title: openTitle, action: #selector(handleOpen(_:)), keyEquivalent: "")
    openItem.target = self
    openItem.isEnabled = true
    menu.addItem(openItem)

    menu.addItem(.separator())

    let quitTitle = String(localized: "status.menu.quit", bundle: .module)
    let quitItem = NSMenuItem(
      title: quitTitle, action: #selector(handleQuit(_:)), keyEquivalent: "q")
    quitItem.target = self
    quitItem.isEnabled = true
    menu.addItem(quitItem)

    return menu
  }

  @objc private func handleOpen(_ sender: Any?) {
    Log.status.info("menu: open")
    onOpen()
  }

  @objc private func handleQuit(_ sender: Any?) {
    Log.status.info("menu: quit")
    onQuit()
  }
}
