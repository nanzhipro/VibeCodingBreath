import Foundation

/// One cell of the 4-2-6-2 breathing cycle from PRD §F-4.3.
enum BreathPhase: Int, CaseIterable, Sendable {
  case inhale
  case holdAfterInhale
  case exhale
  case holdAfterExhale

  var duration: TimeInterval {
    switch self {
    case .inhale: return 4.0
    case .holdAfterInhale: return 2.0
    case .exhale: return 6.0
    case .holdAfterExhale: return 2.0
    }
  }

  /// Target scale for the overlay disc; min = 1.0 (rest), max = 2.0 (fully inhaled).
  var targetScale: CGFloat {
    switch self {
    case .inhale, .holdAfterInhale: return 2.0
    case .exhale, .holdAfterExhale: return 1.0
    }
  }

  var localizedKey: String.LocalizationValue {
    switch self {
    case .inhale: return "breath.phase.inhale"
    case .holdAfterInhale, .holdAfterExhale: return "breath.phase.hold"
    case .exhale: return "breath.phase.exhale"
    }
  }

  var next: BreathPhase {
    let all = BreathPhase.allCases
    let idx = (self.rawValue + 1) % all.count
    return all[idx]
  }
}
