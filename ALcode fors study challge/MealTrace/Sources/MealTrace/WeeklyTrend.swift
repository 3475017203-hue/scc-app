import Foundation

/// 一条记录：某一天、某道菜、营养与溯源结论。
struct DayRecord: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let menu: LunchMenu
    let overHarvestedItems: Int
}

/// 把一周的记录变成一个**趋势**，而不是一句"今天缺钙"。
///
/// 这是本作品真正的价值所在：单日看不出问题，
/// 连续七天都缺才是问题——但也要防止把噪声当趋势。
struct WeeklyTrend {
    let days: [DayRecord]

    var coverageDays: Int { days.count }

    func averageRatio(_ keyPath: KeyPath<NutrientProfile, Double>, need: Double) -> Double {
        guard !days.isEmpty, need > 0 else { return 0 }
        let sum = days.reduce(0.0) { $0 + $1.menu.total(keyPath) }
        return sum / Double(days.count) / need
    }

    /// 判定门槛：至少 4 天记录，且平均比例低于阈值。
    /// 少于 4 天就下"长期问题"的结论，是在制造焦虑。
    func calciumTrend() -> Finding? {
        finding(title: "钙", need: 800, keyPath: \.calcium, lowRatio: 0.6)
    }

    func vitaminATrend() -> Finding? {
        finding(title: "维生素 A", need: 500, keyPath: \.vitaminA, lowRatio: 0.6)
    }

    func proteinTrend() -> Finding? {
        finding(title: "蛋白质", need: 60, keyPath: \.protein, lowRatio: 0.7)
    }

    var allFindings: [Finding] {
        [calciumTrend(), vitaminATrend(), proteinTrend()].compactMap { $0 }
    }

    /// 超期采收出现的天数——这个比营养缺口更该先管
    var overHarvestDays: Int {
        days.filter { $0.overHarvestedItems > 0 }.count
    }

    private func finding(title: String, need: Double, keyPath: KeyPath<NutrientProfile, Double>, lowRatio: Double) -> Finding? {
        guard coverageDays >= 4 else { return nil }
        let ratio = averageRatio(keyPath, need: need)
        guard ratio < lowRatio else { return nil }
        return Finding(title: title, ratio: ratio, days: coverageDays)
    }
}

struct Finding: Identifiable, Hashable {
    let id = UUID()
    let title: String
    /// 占每日参考值的平均比例
    let ratio: Double
    let days: Int

    var percent: Int { Int(ratio * 100) }

    var advice: String {
        if ratio < 0.35 {
            return "连续 \(days) 天，\(title)平均只有参考值的 \(percent)%。这已经不是一顿饭的问题，建议和老师或校医聊一次。"
        }
        return "连续 \(days) 天，\(title)平均 \(percent)%。一周里挑两天补上就行，不必天天盯着。"
    }
}
