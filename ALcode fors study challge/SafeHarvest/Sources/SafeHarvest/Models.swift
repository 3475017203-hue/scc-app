import Foundation

/// 作物。安全间隔期因作物而异——同一瓶药，叶菜要 7 天，某些豆类只要 3 天。
struct Crop: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let emoji: String

    static let common: [Crop] = [
        Crop(id: "leafy",   name: "叶菜类", emoji: "🥬"),
        Crop(id: "bean",    name: "豆类",   emoji: "🫛"),
        Crop(id: "cucurb",  name: "瓜果类", emoji: "🥒"),
        Crop(id: "solanum", name: "茄果类", emoji: "🍅"),
        Crop(id: "root",    name: "根茎类", emoji: "🥕"),
        Crop(id: "orchard", name: "果树类", emoji: "🍊")
    ]
}

/// 标签上能被读到的字段。读不到就是 .unknown —— **绝不猜**。
enum LabelField: Hashable {
    case unknown
    case text(String)
    case days(Int)

    var display: String {
        switch self {
        case .unknown: "未读到"
        case .text(let t): t
        case .days(let d): "\(d) 天"
        }
    }

    var dayCount: Int? {
        if case .days(let d) = self { return d }
        return nil
    }
}

struct LabelReading: Codable, Hashable {
    var pesticideName: LabelField = .unknown
    var activeIngredient: LabelField = .unknown
    /// 安全间隔期（天）
    var safetyIntervalDays: LabelField = .unknown
    /// 每季最大使用次数
    var maxApplications: LabelField = .unknown
    /// OCR 原文，保留以便人工核对
    var rawText: String = ""

    /// 哪些字段没读到——UI 必须明确告诉用户"哪里要手填"
    var missing: [String] {
        var result: [String] = []
        if case .unknown = pesticideName { result.append("农药名称") }
        if case .unknown = safetyIntervalDays { result.append("安全间隔期") }
        return result
    }

    var isUsable: Bool { safetyIntervalDays.dayCount != nil }
}

/// 一次施药记录
struct Application: Identifiable, Codable, Hashable {
    let id: UUID
    var crop: Crop
    var label: LabelReading
    var appliedOn: Date
    var note: String = ""

    init(id: UUID = UUID(), crop: Crop, label: LabelReading, appliedOn: Date, note: String = "") {
        self.id = id
        self.crop = crop
        self.label = label
        self.appliedOn = appliedOn
        self.note = note
    }
}

/// 计算结果：最早可采收日 + 倒计时
struct HarvestWindow: Hashable {
    let earliestHarvestDate: Date
    let intervalDays: Int
    let appliedOn: Date

    func daysRemaining(from now: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: earliestHarvestDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func isReady(on date: Date, calendar: Calendar = .current) -> Bool {
        !daysRemaining(from: date, calendar: calendar).isNegative
    }

    /// 违规采收：采收日早于最早可采收日
    func isViolation(harvestedOn: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: harvestedOn) < calendar.startOfDay(for: earliestHarvestDate)
    }
}
