import SwiftUI

extension Color {
    // Primary accent — brick red
    static let toshoRed = Color(red: 0.620, green: 0.192, blue: 0.176)
    static let toshoRedLight = Color(red: 0.620, green: 0.192, blue: 0.176).opacity(0.10)

    // Alias kept for any remaining references in other files
    static let toshoGreen = Color(red: 0.620, green: 0.192, blue: 0.176)
    static let toshoGreenLight = Color(red: 0.620, green: 0.192, blue: 0.176).opacity(0.10)

    // Accent — warm amber for alerts / highlights
    static let toshoAmber = Color(red: 0.900, green: 0.680, blue: 0.180)
    static let toshoAmberLight = Color(red: 0.900, green: 0.680, blue: 0.180).opacity(0.15)

    // Background — ライトモード: ウォームオフホワイト / ダークモード: ダークグレー
    static let toshoCream = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)
            : UIColor(red: 0.972, green: 0.960, blue: 0.945, alpha: 1)
    })

    // Legacy
    static let toshoBrown = Color(red: 0.545, green: 0.369, blue: 0.235)

    // Text — ライトモード: ほぼ黒 / ダークモード: ほぼ白
    static let toshoText = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1)
            : UIColor(red: 0.098, green: 0.098, blue: 0.118, alpha: 1)
    })

    static let toshoSubtext = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 0.50)
            : UIColor(red: 0.098, green: 0.098, blue: 0.118, alpha: 0.42)
    })

    // Cards — ライトモード: 白 / ダークモード: 少し明るいダーク面
    static let toshoCard = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1)
            : UIColor.white
    })
}

extension LibraryCategory {
    var color: Color {
        switch self {
        case .small:   return Color(red: 0.13, green: 0.63, blue: 0.65)
        case .medium:  return Color(red: 0.20, green: 0.55, blue: 0.33)
        case .large:   return Color(red: 0.18, green: 0.38, blue: 0.78)
        case .univ:    return Color(red: 0.50, green: 0.22, blue: 0.72)
        case .special: return Color(red: 0.87, green: 0.43, blue: 0.12)
        case .bm:      return Color(red: 0.75, green: 0.55, blue: 0.08)
        }
    }
}

struct ToshoTheme {
    static let cornerRadius: CGFloat = 18
    static let cardCornerRadius: CGFloat = 22
    static let smallCornerRadius: CGFloat = 12
    static let shadowRadius: CGFloat = 12
    static let shadowOpacity: Double = 0.07

    // Gradient stops used in LibraryCard image overlays
    static let headerDeep  = Color(red: 0.420, green: 0.095, blue: 0.085)
    static let headerMid   = Color(red: 0.620, green: 0.192, blue: 0.176)
    static let headerLight = Color(red: 0.780, green: 0.350, blue: 0.280)
}
