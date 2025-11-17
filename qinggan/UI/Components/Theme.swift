import SwiftUI

struct AppTheme {
    static let brand = Color(hex: 0x22C55E)
    static let brandLight = Color(hex: 0xD1FADF)
    static let cardShadow = Color.black.opacity(0.05)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >> 8) & 0xff) / 255.0
        let b = Double(hex & 0xff) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}