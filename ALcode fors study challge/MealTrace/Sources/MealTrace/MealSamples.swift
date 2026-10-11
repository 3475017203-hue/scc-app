import Foundation

enum MealSamples {
    /// 校内公示屏上常见的排版：字段名不统一、冒号时有时无
    static let boardText = """
    批次 B-20261012 品名 小白菜 产地 青浦蔬菜基地
    安全间隔期 7天 末次施药 20261005
    采收日期 20261011 供应商 城东配送
    """

    /// 一条**超期采收**的记录：施药 10/05、间隔 7 天，10/11 就采收了
    static let overdueText = boardText

    /// 合规的一批：施药 10/01，10/12 采收
    static let compliantText = """
    品名:小白菜 产地:青浦蔬菜基地
    安全间隔:14天 末次施药:20260928
    采收:20261012 供应商:城东配送
    """

    static func menu(with trace: BatchTrace?, compliant: Bool) -> LunchMenu {
        var cabbage = LunchMenu.Dish(name: "清炒小白菜", grams: 120, nutrient: .cabbage)
        cabbage.trace = trace
        _ = compliant
        return LunchMenu(date: Date(), items: [
            LunchMenu.Dish(name: "米饭", grams: 150, nutrient: .rice),
            cabbage,
            LunchMenu.Dish(name: "番茄炒蛋", grams: 100, nutrient: .pork),
            LunchMenu.Dish(name: "豆腐汤", grams: 100, nutrient: .tofu),
            LunchMenu.Dish(name: "凉拌胡萝卜", grams: 60, nutrient: .carrot)
        ])
    }

    /// 一周的记录：第 3 天那批超期采收，其余合规；
    /// 钙与维生素 A 连续偏低——这才是"长期问题"的样本。
    static func weekRecords() -> [DayRecord] {
        let cal = Calendar.current
        let compliant = parseText(compliantText)
        let overdue = parseText(boardText)
        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let badDay = offset == 3
            let menu = menu(with: badDay ? overdue : compliant, compliant: !badDay)
            return DayRecord(date: date, menu: menu, overHarvestedItems: badDay ? 1 : 0)
        }
    }

    static func parseText(_ text: String) -> BatchTrace? {
        TraceParser().parse(text)
    }
}
