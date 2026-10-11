import SwiftUI

enum SignalTheme {
    static let title = Font.system(size: 32, weight: .heavy, design: .rounded)
    static let section = Font.system(size: 21, weight: .bold, design: .rounded)
    static let body = Font.system(size: 19, weight: .medium, design: .rounded)
}

extension SoundEvent.Severity {
    var label: String {
        switch self {
        case .low: "不急"
        case .medium: "可以去"
        case .high: "快去看看"
        case .critical: "马上起身"
        }
    }
}
