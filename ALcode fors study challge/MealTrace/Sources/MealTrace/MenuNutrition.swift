import Foundation

/// 今天的午餐：一道菜 + 主食 + 份量。
struct LunchMenu {
    let date: Date
    let items: [Dish]

    struct Dish: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let grams: Int
        let nutrient: NutrientProfile
        /// 这道菜里有没有被追溯到的批次
        var trace: BatchTrace?
    }

    func total(_ keyPath: KeyPath<NutrientProfile, Double>) -> Double {
        items.reduce(0) { $0 + $1.grams * $1.nutrient[keyPath: keyPath] / 100 }
    }
}

/// 每 100 克的营养含量（粗略值，用于演示）
struct NutrientProfile {
    let protein: Double
    let fat: Double
    let carbs: Double
    let calcium: Double
    let vitaminA: Double

    static let rice = NutrientProfile(protein: 2.6, fat: 0.3, carbs: 25.9, calcium: 7, vitaminA: 0)
    static let cabbage = NutrientProfile(protein: 1.5, fat: 0.1, carbs: 3.3, calcium: 50, vitaminA: 20)
    static let pork = NutrientProfile(protein: 20.0, fat: 6.2, carbs: 0.7, calcium: 6, vitaminA: 44)
    static let tofu = NutrientProfile(protein: 8.1, fat: 3.7, carbs: 2.2, calcium: 164, vitaminA: 5)
    static let carrot = NutrientProfile(protein: 0.9, fat: 0.2, carbs: 8.8, calcium: 32, vitaminA: 688)
}

/// 7–12 岁儿童每日参考摄入量（中国居民膳食指南营养素参考值，演示用粗略值）
struct NutritionTarget {
    let protein: Double = 60
    let fat: Double = 60
    let calcium: Double = 800
    let vitaminA: Double = 500

    static func evaluate(_ menu: LunchMenu) -> [Gap] {
        var gaps: [Gap] = []
        gaps.append(gap(title: "蛋白质", need: 60, actual: menu.total(\.protein)))
        gaps.append(gap(title: "钙", need: 800, actual: menu.total(\.calcium)))
        gaps.append(gap(title: "维生素A", need: 500, actual: menu.total(\.vitaminA)))
        return gaps.filter { $0.status != .ok }
    }

    private static func gap(title: String, need: Double, actual: Double) -> Gap {
        let ratio = need > 0 ? actual / need : 0
        let status: Gap.Status = ratio < 0.6 ? .low : (ratio < 0.85 ? .aBitLow : .ok)
        return Gap(title: title, need: need, actual: actual, status: status)
    }
}

struct Gap: Identifiable, Hashable {
    enum Status: String, Hashable {
        case ok = "够"
        case aBitLow = "偏低"
        case low = "明显不足"
    }

    let id = UUID()
    let title: String
    let need: Double
    let actual: Double
    let status: Status

    var percent: Int { need > 0 ? Int(actual / need * 100) : 0 }
    var advice: String {
        switch status {
        case .ok: "今天这一餐够了。"
        case .aBitLow: "\(title)只有参考值的 \(percent)%，一周里有几天补上就行，不用天天盯着。"
        case .low: "\(title)只有参考值的 \(percent)%。这是长期问题，建议和学校或医生聊一次，而不是靠某一顿饭补。"
        }
    }
}
