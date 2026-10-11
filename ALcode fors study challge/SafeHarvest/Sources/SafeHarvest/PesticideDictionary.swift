import Foundation

/// 离线农药小词典：常见蔬菜农药 → 各作物大类安全间隔期。
///
/// 为什么要它：OCR 会把「7 天」读成「1 天」，把「17」读成「71」。
/// 标签上的一个数字错了，就是一批菜能不能吃的问题。
/// 词典不替代标签，而是**在标签之外多一个独立信源**——
/// 两者不一致时，App 的正确做法是停下来让人核对，而不是选一个显示。
struct PesticideDictionary {
    struct Entry: Identifiable, Hashable {
        let id: String
        /// 有效成分（按成分归并：同一成分的不同商品名间隔期一致）
        let activeIngredient: String
        let tradeNames: [String]
        /// 作物大类 id → 安全间隔天数
        let intervals: [String: Int]
        /// 数据来源与抓取日期。**没有来源的天数是不可信的**——
        /// 宁可显示"来源不明"，也不要让人以为这是权威数据。
        let source: Source

        func interval(for crop: Crop) -> Int? { intervals[crop.id] }
    }

    struct Source: Hashable {
        /// 依据什么整理（公开标签、说明书、地方标准等）
        let basis: String
        /// 整理日期
        let retrievedOn: String
        /// 是否经过权威机构校对。false 时 UI 必须显著提示
        let verified: Bool

        var line: String {
            verified
                ? "来源：\(basis)（整理于 \(retrievedOn)，已校对）"
                : "来源：\(basis)（整理于 \(retrievedOn)）· **未经过权威机构校对，请以药瓶标签为准**"
        }
    }

    enum LookupResult: Hashable {
        case matched(Entry, intervalDays: Int)
        case mismatch(label: Int, dictionary: Int)
        case notFound
        case noIntervalForCrop
    }

    let entries: [Entry]

    static let standard = PesticideDictionary(entries: [
        Entry(id: "dimethomorph",
              activeIngredient: "烯酰吗啉",
              tradeNames: ["安克美"],
              intervals: ["leafy": 7, "cucurb": 7, "solanum": 7, "bean": 5, "root": 5, "orchard": 14],
              source: Source(basis: "常见蔬菜用药说明书整理", retrievedOn: "2026-10", verified: false)),
        Entry(id: "matrine",
              activeIngredient: "苦参碱",
              tradeNames: ["苦参碱"],
              intervals: ["leafy": 3, "cucurb": 3, "bean": 3, "solanum": 3],
              source: Source(basis: "常见蔬菜用药说明书整理", retrievedOn: "2026-10", verified: false)),
        Entry(id: "chlorothalonil",
              activeIngredient: "百菌清",
              tradeNames: ["达科宁"],
              intervals: ["leafy": 3, "cucurb": 3, "solanum": 3, "bean": 3, "root": 3],
              source: Source(basis: "常见蔬菜用药说明书整理", retrievedOn: "2026-10", verified: false)),
        Entry(id: "pyraclostrobin",
              activeIngredient: "吡唑醚菌酯",
              tradeNames: ["吡唑醚菌酯"],
              intervals: ["leafy": 7, "cucurb": 7, "solanum": 7, "orchard": 14],
              source: Source(basis: "常见蔬菜用药说明书整理", retrievedOn: "2026-10", verified: false)),
        Entry(id: "glufosinate",
              activeIngredient: "草铵膦",
              tradeNames: ["克草踪"],
              intervals: ["orchard": 30, "root": 15, "leafy": 15],
              source: Source(basis: "常见蔬菜用药说明书整理", retrievedOn: "2026-10", verified: false)),
        Entry(id: "lambda_cyhalothrin",
              activeIngredient: "高效氯氟氰菊酯",
              tradeNames: ["高效氯氟氰菊酯"],
              intervals: ["leafy": 7, "bean": 7, "solanum": 7, "cucurb": 7],
              source: Source(basis: "常见蔬菜用药说明书整理", retrievedOn: "2026-10", verified: false))
    ])

    /// 按有效成分或商品名模糊匹配，再按作物取天数
    func lookup(reading: LabelReading, crop: Crop) -> LookupResult {
        guard let name = textValue(reading.activeIngredient) ?? textValue(reading.pesticideName) else {
            return .notFound
        }
        let hit = entries.first { entry in
            name.contains(entry.activeIngredient) || entry.activeIngredient.contains(name)
                || entry.tradeNames.contains { $0.contains(name) || name.contains($0) }
        }
        guard let entry = hit else { return .notFound }
        guard let interval = entry.interval(for: crop) else { return .noIntervalForCrop }
        guard let fromLabel = reading.safetyIntervalDays.dayCount else {
            return .matched(entry, intervalDays: interval)
        }
        // 两个信源不一致 → 明确报「对不上」，绝不静默选一个
        if fromLabel == interval { return .matched(entry, intervalDays: interval) }
        return .mismatch(label: fromLabel, dictionary: interval)
    }

    private func textValue(_ field: LabelField) -> String? {
        if case .text(let t) = field { return t }
        return nil
    }
}
