import SwiftUI

/// 为老人阅读优化的视觉：大字号、高对比、暖色底。
enum ElderTheme {
    static let bigTitle = Font.system(size: 34, weight: .heavy, design: .rounded)
    static let sectionTitle = Font.system(size: 22, weight: .bold, design: .rounded)
    static let body = Font.system(size: 20, weight: .medium, design: .rounded)
    static let huge = Font.system(size: 44, weight: .heavy, design: .rounded)

    static let warmBackground = LinearGradient(
        colors: [Color(red: 1.0, green: 0.97, blue: 0.92), Color(red: 0.98, green: 0.93, blue: 0.86)],
        startPoint: .top, endPoint: .bottom
    )

    static func color(for urgency: Urgency) -> Color {
        switch urgency {
        case .routine: .green
        case .soon: .orange
        case .urgent: .deepOrange
        case .emergency: .red
        }
    }
}
