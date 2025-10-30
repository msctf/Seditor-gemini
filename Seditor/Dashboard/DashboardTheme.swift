import SwiftUI

enum DashboardTheme {
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.06, green: 0.07, blue: 0.09),
            Color(red: 0.08, green: 0.09, blue: 0.13),
            Color(red: 0.04, green: 0.05, blue: 0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panelBackground = Color(red: 0.11, green: 0.12, blue: 0.17, opacity: 0.85)
    static let outline = Color(red: 0.27, green: 0.29, blue: 0.36, opacity: 0.4)
    static let separator = Color.white.opacity(0.06)
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.6)
}

struct Metric: Identifiable {
    let label: String
    let value: String
    let icon: String
    let accent: Color

    var id: String { label }
}

extension Color {
    static let accentBlue = Color(red: 0.37, green: 0.69, blue: 0.98)
    static let accentPurple = Color(red: 0.70, green: 0.47, blue: 0.98)
    static let accentCyan = Color(red: 0.43, green: 0.80, blue: 0.89)
    static let accentOrange = Color(red: 0.99, green: 0.61, blue: 0.33)
    static let accentPink = Color(red: 0.94, green: 0.44, blue: 0.71)
    static let accentTeal = Color(red: 0.32, green: 0.76, blue: 0.70)
    static let accentYellow = Color(red: 0.99, green: 0.82, blue: 0.41)
}
