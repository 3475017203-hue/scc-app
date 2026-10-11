import Foundation

/// 一批菜的来路。学校食堂公示屏、二维码、供应商台账里通常只有这些字段。
struct BatchTrace {
    let batchId: String
    let vegetable: String
    let farm: String
    let lastSprayedOn: Date
    /// 该蔬菜的安全间隔期（天）
    let safetyIntervalDays: Int
    let harvestedOn: Date
    let supplier: String

    /// 这批菜采收时有没有到日子
    func isSafe(on date: Date, calendar: Calendar = .current) -> Bool {
        let ready = calendar.date(byAdding: .day, value: safetyIntervalDays, to: lastSprayedOn)
        guard let ready != nil else { return false }
        return calendar.startOfDay(for: harvestedOn) >= calendar.startOfDay(for: ready!)
    }

    /// 从最后一次施药到今天过了多少天
    func daysSinceSpray(on date: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: lastSprayedOn)
        let to = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    func verdict(on date: Date, calendar: Calendar = .current) -> Verdict {
        isSafe(on: date, calendar: calendar) ? .ok : .overHarvested
    }

    enum Verdict {
        case ok
        case overHarvested
    }
}
