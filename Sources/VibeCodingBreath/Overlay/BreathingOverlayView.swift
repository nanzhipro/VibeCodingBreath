import SwiftUI

struct BreathingOverlayView: View {
    let engine: BreathingEngine
    @Environment(\.colorScheme) private var colorScheme
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: Palette.haloStops(for: colorScheme),
                        center: .center,
                        startRadius: 0,
                        endRadius: Constants.minDiameter / 2
                    )
                )
                .frame(
                    width: Constants.minDiameter,
                    height: Constants.minDiameter
                )
                .blur(radius: 24)
                .scaleEffect(scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
        .onAppear {
            scale = engine.phase.targetScale
        }
        .onChange(of: engine.phase) { _, newPhase in
            withAnimation(.easeInOut(duration: newPhase.duration)) {
                scale = newPhase.targetScale
            }
        }
    }
}
