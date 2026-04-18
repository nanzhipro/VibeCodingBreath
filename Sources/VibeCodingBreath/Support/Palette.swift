import Foundation
import SwiftUI

/// Color palette for the breathing overlay; adapts subtly between light & dark mode.
struct BreathPalette: Sendable {
  let baseColor: Color

  static let `default` = BreathPalette(baseColor: Color(hex: Constants.primaryHex))

  /// Radial gradient used by the overlay, with transparency on the outside.
  func gradient(for scheme: ColorScheme) -> RadialGradient {
    let inner = baseColor.opacity(scheme == .dark ? 0.55 : 0.65)
    let mid = baseColor.opacity(scheme == .dark ? 0.30 : 0.35)
    let outer = baseColor.opacity(0.0)
    return RadialGradient(
      gradient: Gradient(colors: [inner, mid, outer]),
      center: .center,
      startRadius: 0,
      endRadius: Constants.minDiameter / 2
    )
  }
}

extension Color {
  /// Parse `#RRGGBB` (or `RRGGBB`) hex strings. Falls back to .gray on bad input.
  init(hex: String) {
    let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "#", with: "")
    guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else {
      self = .gray
      return
    }
    let r = Double((value >> 16) & 0xFF) / 255.0
    let g = Double((value >> 8) & 0xFF) / 255.0
    let b = Double(value & 0xFF) / 255.0
    self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
  }
}
