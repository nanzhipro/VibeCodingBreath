import SwiftUI

enum Palette {
    static let primary: Color = Color(hex: Constants.primaryHex)

    static func haloStops(for scheme: ColorScheme) -> [Color] {
        switch scheme {
        case .dark:
            return [
                primary.opacity(0.55),
                primary.opacity(0.30),
                primary.opacity(0.00)
            ]
        default:
            return [
                primary.opacity(0.65),
                primary.opacity(0.35),
                primary.opacity(0.00)
            ]
        }
    }
}

extension Color {
    init(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xff) / 255.0
        let g = Double((value >> 8) & 0xff) / 255.0
        let b = Double(value & 0xff) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
