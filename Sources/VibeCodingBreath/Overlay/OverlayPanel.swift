import AppKit

/// Borderless, transparent, click-through panel used to host the breathing overlay.
/// Configuration is locked down per TECH_PLAN §3.1 so it cannot steal focus or block input.
final class OverlayPanel: NSPanel {
  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    level = .statusBar
    ignoresMouseEvents = true
    isMovableByWindowBackground = false
    hidesOnDeactivate = false
    collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
      .ignoresCycle,
      .fullScreenAuxiliary,
    ]
    isReleasedWhenClosed = false
    animationBehavior = .none
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}
