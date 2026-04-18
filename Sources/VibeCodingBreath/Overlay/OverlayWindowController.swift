import AppKit
import SwiftUI

/// Owns the overlay panel + hosting view and handles fade in/out animation, screen positioning,
/// and engine lifecycle.
@MainActor
final class OverlayWindowController: OverlayPresenting {
  private let panel: OverlayPanel
  private let engine: BreathingEngine
  private var screenObserver: NSObjectProtocol?

  private(set) var isVisible: Bool = false

  init(engine: BreathingEngine = BreathingEngine()) {
    self.engine = engine
    self.panel = OverlayPanel()

    let view = BreathingOverlayView(engine: engine)
    let hosting = NSHostingView(rootView: view)
    hosting.frame = NSRect(
      x: 0, y: 0,
      width: Constants.maxDiameter + Constants.overlayPadding,
      height: Constants.maxDiameter + Constants.overlayPadding
    )
    panel.contentView = hosting
    panel.setContentSize(hosting.frame.size)

    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.repositionIfVisible() }
    }
  }

  deinit {
    // Observer cleanup happens via NotificationCenter retaining a weak self in the block.
  }

  func show() {
    guard !isVisible else { return }
    guard let screen = NSScreen.main else {
      Log.overlay.warning("show() with no main screen; aborting")
      return
    }
    positionPanel(on: screen)
    panel.alphaValue = 0
    panel.orderFrontRegardless()
    engine.start()
    isVisible = true

    NSAnimationContext.runAnimationGroup { ctx in
      ctx.duration = Constants.fadeIn
      ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().alphaValue = 1.0
    }
    Log.overlay.info("overlay shown")
  }

  func hide() {
    guard isVisible else { return }
    isVisible = false
    let panelRef = panel
    let engineRef = engine
    NSAnimationContext.runAnimationGroup(
      { ctx in
        ctx.duration = Constants.fadeOut
        ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
        panelRef.animator().alphaValue = 0.0
      },
      completionHandler: {
        // Stop engine and order out only if we are still hidden.
        engineRef.stop()
        panelRef.orderOut(nil)
      })
    Log.overlay.info("overlay hiding")
  }

  private func repositionIfVisible() {
    guard isVisible, let screen = NSScreen.main else { return }
    positionPanel(on: screen)
  }

  private func positionPanel(on screen: NSScreen) {
    let size = panel.frame.size
    let frame = screen.frame
    let origin = NSPoint(
      x: frame.midX - size.width / 2,
      y: frame.midY - size.height / 2
    )
    panel.setFrameOrigin(origin)
  }
}
