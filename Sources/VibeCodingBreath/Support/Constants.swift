import Foundation
import SwiftUI

/// Centralized default constants for the MVP. Values come from PRD §11 and TECH_PLAN §1.
enum Constants {
  // MARK: Idle detection
  static let idleThreshold: TimeInterval = 5.0
  static let pollInterval: TimeInterval = 0.5

  // MARK: Overlay sizing
  static let minDiameter: CGFloat = 120
  static let maxDiameter: CGFloat = 320
  static let overlayPadding: CGFloat = 64

  // MARK: Animation
  static let fadeIn: TimeInterval = 0.4
  static let fadeOut: TimeInterval = 0.2

  // MARK: Visual
  static let primaryHex: String = "#7FB3D5"

  // MARK: Bundle
  static let bundleIdentifier: String = "pro.nanzhi.VibeCodingBreath"
  static let appDisplayName: String = "VibeCodingBreath"
}
