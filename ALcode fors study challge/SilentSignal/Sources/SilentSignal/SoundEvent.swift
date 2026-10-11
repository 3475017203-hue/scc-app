import Foundation

/// 家里那些「错过了就是大事」的声音。
enum SoundEvent: String, CaseIterable, Identifiable, Codable {
    case knock
    case babyCry
    case kettle
    case smokeAlarm
    case waterLeak
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .knock: "有人在敲门"
        case .babyCry: "孩子在哭"
        case .kettle: "水开了 / 锅在响"
        case .smokeAlarm: "烟雾报警器"
        case .waterLeak: "漏水"
        case .unknown: "不确定的声音"
        }
    }

    var symbol: String {
        switch self {
        case .knock: "hand.tap.fill"
        case .babyCry: "figure.child.circle.fill"
        case .kettle: "cup.and.saucer.fill"
        case .smokeAlarm: "exclamationmark.triangle.fill"
        case .waterLeak: "drop.triangle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    /// 紧急度决定震动强度与是否推送给家人
    var severity: Severity {
        switch self {
        case .smokeAlarm, .waterLeak: .critical
        case .babyCry: .high
        case .kettle: .medium
        case .knock, .unknown: .low
        }
    }

    enum Severity: Int, Comparable, Codable {
        case low = 0, medium = 1, high = 2, critical = 3
        static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue }
    }

    /// 震动本身说不出语义，得靠一句人话补上
    var meaning: String {
        switch self {
        case .knock: "有人在门外，可能是快递或邻居"
        case .babyCry: "孩子可能需要你过去看看"
        case .kettle: "厨房有东西烧开了，可能要糊锅"
        case .smokeAlarm: "可能有火灾风险，请立即查看"
        case .waterLeak: "家里可能在漏水，电器有触电风险"
        case .unknown: "检测到一个声音，但没能判断是什么"
        }
    }
}

struct Detection: Identifiable, Hashable, Codable {
    let id: UUID
    let event: SoundEvent
    let confidence: Double
    let at: Date

    init(id: UUID = UUID(), event: SoundEvent, confidence: Double, at: Date = Date()) {
        self.id = id
        self.event = event
        self.confidence = confidence
        self.at = at
    }
}
