import SwiftUI

/// SwiftUI overlay rendering the soft breathing disc.
struct BreathingOverlayView: View {
  let engine: BreathingEngine
  var palette: BreathPalette = .default

  @Environment(\.colorScheme) private var colorScheme
  @State private var scale: CGFloat = 1.0

  var body: some View {
    ZStack {
      Circle()
        .fill(palette.gradient(for: colorScheme))
        .frame(width: Constants.minDiameter, height: Constants.minDiameter)
        .blur(radius: 24)
        .scaleEffect(scale)
        .accessibilityHidden(true)
    }
    .frame(
      width: Constants.maxDiameter + Constants.overlayPadding,
      height: Constants.maxDiameter + Constants.overlayPadding
    )
    .onAppear {
      scale = engine.phase.targetScale
      animate(to: engine.phase)
    }
    .onChange(of: engine.phase) { _, newPhase in
      animate(to: newPhase)
    }
  }

  private func animate(to phase: BreathPhase) {
    withAnimation(.easeInOut(duration: phase.duration)) {
      scale = phase.targetScale
    }
  }
}
