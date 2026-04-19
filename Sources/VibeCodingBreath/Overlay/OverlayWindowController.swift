import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController: OverlayControlling {
    private var panel: OverlayPanel?
    private let engine: BreathingEngine
    private var screenObservationTask: Task<Void, Never>?

    init(engine: BreathingEngine) {
        self.engine = engine
    }

    func show() {
        guard let screen = NSScreen.main else {
            AppLogger.overlay.error("show() aborted: no main screen")
            return
        }
        let p = panel ?? makePanel(on: screen)
        if panel == nil {
            panel = p
            observeScreenChanges()
        }
        recenter(on: screen)
        p.alphaValue = 0
        p.orderFrontRegardless()
        engine.start()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Constants.fadeIn
            p.animator().alphaValue = 1.0
        }
    }

    func hide() {
        guard let p = panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Constants.fadeOut
            p.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.engine.stop()
                self.panel?.orderOut(nil)
            }
        })
    }

    func cleanup() {
        screenObservationTask?.cancel()
        screenObservationTask = nil
        engine.stop()
        panel?.orderOut(nil)
        panel = nil
    }

    private func makePanel(on screen: NSScreen) -> OverlayPanel {
        let side = Constants.maxDiameter + Constants.overlayPadding
        let frame = frame(for: side, on: screen)
        let p = OverlayPanel(contentRect: frame)
        let hosting = NSHostingView(rootView: BreathingOverlayView(engine: engine))
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        p.contentView = hosting
        return p
    }

    private func recenter(on screen: NSScreen) {
        guard let p = panel else { return }
        let side = Constants.maxDiameter + Constants.overlayPadding
        p.setFrame(frame(for: side, on: screen), display: false)
    }

    private func frame(for side: CGFloat, on screen: NSScreen) -> NSRect {
        NSRect(
            x: screen.frame.midX - side / 2,
            y: screen.frame.midY - side / 2,
            width: side,
            height: side
        )
    }

    private func observeScreenChanges() {
        screenObservationTask?.cancel()
        screenObservationTask = Task { @MainActor [weak self] in
            let stream = NotificationCenter.default.notifications(
                named: NSApplication.didChangeScreenParametersNotification
            )
            for await _ in stream {
                if Task.isCancelled { return }
                self?.handleScreenChange()
            }
        }
    }

    private func handleScreenChange() {
        guard let screen = NSScreen.main else {
            panel?.orderOut(nil)
            return
        }
        recenter(on: screen)
    }
}
