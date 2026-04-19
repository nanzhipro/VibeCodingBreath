import Foundation

enum Constants {
    static let idleThreshold: TimeInterval = 5.0
    static let pollInterval: TimeInterval = 0.5

    static let minDiameter: CGFloat = 120
    static let maxDiameter: CGFloat = 320
    static let overlayPadding: CGFloat = 64

    static let fadeIn: TimeInterval = 0.4
    static let fadeOut: TimeInterval = 0.2

    static let primaryHex: String = "#7FB3D5"
    static let bundleIdentifier: String = "pro.nanzhi.VibeCodingBreath"
}

enum AppResources {
    static var bundle: Bundle { .module }
}
