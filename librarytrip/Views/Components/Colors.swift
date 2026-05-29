import SwiftUI

extension Color {
    static let toshoGreen = Color(red: 0.176, green: 0.467, blue: 0.365)
    static let toshoGreenLight = Color(red: 0.176, green: 0.467, blue: 0.365).opacity(0.12)
    static let toshoAmber = Color(red: 0.910, green: 0.659, blue: 0.220)
    static let toshoCream = Color(red: 0.980, green: 0.973, blue: 0.957)
    static let toshoBrown = Color(red: 0.545, green: 0.369, blue: 0.235)
    static let toshoText = Color(red: 0.102, green: 0.102, blue: 0.180)
    static let toshoSubtext = Color(red: 0.102, green: 0.102, blue: 0.180).opacity(0.5)
    static let toshoCard = Color.white
}

struct ToshoTheme {
    static let cornerRadius: CGFloat = 16
    static let cardCornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 10
    static let shadowRadius: CGFloat = 8
    static let shadowOpacity: Double = 0.08
}
