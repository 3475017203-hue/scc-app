import SwiftUI

enum HarvestTheme {
    static let title = Font.system(size: 32, weight: .heavy, design: .rounded)
    static let section = Font.system(size: 21, weight: .bold, design: .rounded)
    static let body = Font.system(size: 19, weight: .medium, design: .rounded)
    /// 田里戴着手套、太阳底下看手机——字号必须够大，对比必须够高。
    static let counter = Font.system(size: 76, weight: .black, design: .rounded)

    static let fieldBackground = LinearGradient(
        colors: [Color(red: 0.96, green: 0.98, blue: 0.93), Color(red: 0.90, green: 0.95, blue: 0.86)],
        startPoint: .top, endPoint: .bottom
    )

    static func color(for window: HarvestWindow, today: Date = Date()) -> Color {
        let days = window.daysRemaining(from: today)
        if days < 0 { return .green }
        if days <= 2 { return .orange }
        return .green.opacity(0.85)
    }
}

extension View {
    func fieldCard() -> some View {
        padding(16)
            .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.green.opacity(0.2), lineWidth: 1))
    }
}
