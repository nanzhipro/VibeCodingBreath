import Foundation
import CoreGraphics

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

    var targetScale: CGFloat {
        switch self {
        case .inhale, .holdAfterInhale: return 2.0
        case .exhale, .holdAfterExhale: return 1.0
        }
    }

    var localizationKey: String {
        switch self {
        case .inhale: return "phase.inhale"
        case .holdAfterInhale: return "phase.hold.afterInhale"
        case .exhale: return "phase.exhale"
        case .holdAfterExhale: return "phase.hold.afterExhale"
        }
    }
}
