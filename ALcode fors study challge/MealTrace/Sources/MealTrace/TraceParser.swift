import Foundation

/// 解析学校食堂公示或溯源码上的文字。
/// 读不到就返回 nil，**绝不用常识补**——
/// "读不出来"和"读成 0 天"在食安里是两种完全不同的事。
struct TraceParser {
    func parse(_ raw: String, today: Date = Date(), calendar: Calendar = .current) -> BatchTrace? {
        let text = normalize(raw)
        guard let vegetable = value(after: ["品名", "蔬菜", "品种"], in: text) else { return nil }
        guard let farm = value(after: ["产地", "基地", "来源"], in: text) else { return nil }
        guard let interval = number(after: ["安全间隔期", "安全间隔"], in: text) else { return nil }
        guard let sprayed = date(after: ["末次施药", "最后施药", "施药日期"], in: text, today: today, calendar: calendar) else { return nil }
        guard let harvested = date(after: ["采收日期", "采摘日期", "采收"], in: text, today: today, calendar: calendar) else { return nil }
        let batchId = value(after: ["批次", "批号"], in: text) ?? "未标注批次"
        let supplier = value(after: ["供应商", "配送"], in: text) ?? "未标注供应商"
        return BatchTrace(batchId: batchId, vegetable: vegetable, farm: farm,
                          lastSprayedOn: sprayed, safetyIntervalDays: interval,
                          harvestedOn: harvested, supplier: supplier)
    }

    /// 哪几个字段读不出来——UI 要明确告诉家长"哪里需要去问食堂"
    func missingFields(in raw: String) -> [String] {
        let text = normalize(raw)
        var missing: [String] = []
        if value(after: ["品名", "蔬菜", "品种"], in: text) == nil { missing.append("蔬菜名称") }
        if value(after: ["产地", "基地", "来源"], in: text) == nil { missing.append("产地") }
        if number(after: ["安全间隔期", "安全间隔"], in: text) == nil { missing.append("安全间隔期") }
        if date(after: ["末次施药", "最后施药", "施药日期"], in: text, today: Date(), calendar: .current) == nil { missing.append("末次施药日期") }
        if date(after: ["采收日期", "采摘日期", "采收"], in: text, today: Date(), calendar: .current) == nil { missing.append("采收日期") }
        return missing
    }

    private func normalize(_ raw: String) -> String {
        raw.replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{3000}", with: "")
    }

    private func value(after keys: [String], in text: String) -> String? {
        for key in keys {
            guard let range = text.range(of: key) else { continue }
            let cleaned = String(text[range.upperBound...].prefix(20)).replacingOccurrences(of: ":", with: "")
            if !cleaned.isEmpty { return String(cleaned.prefix(10)) }
        }
        return nil
    }

    private func number(after keys: [String], in text: String) -> Int? {
        for key in keys {
            guard let range = text.range(of: key) else { continue }
            let digits = leadingDigits(String(text[range.upperBound...].prefix(10)))
            if let value = Int(digits), value >= 0, value <= 90 { return value }
        }
        return nil
    }

    private func date(after keys: [String], in text: String, today: Date, calendar: Calendar) -> Date? {
        for key in keys {
            guard let range = text.range(of: key) else { continue }
            let digits = String(text[range.upperBound...].prefix(16)).filter(\.isNumber)
            guard digits.count >= 8 else { continue }
            guard let month = Int(digits.prefix(2)),
                  let day = Int(digits.dropFirst(2).prefix(2)),
                  let year = Int(digits.dropFirst(4).prefix(4)),
                  (1...12).contains(month), (1...31).contains(day) else { continue }
            var comps = DateComponents()
            comps.year = year < 2000 ? 2000 + year : year
            comps.month = month
            comps.day = day
            if let parsed = calendar.date(from: comps), parsed <= today { return parsed }
        }
        return nil
    }

    private func leadingDigits(_ s: String) -> String {
        var digits = ""
        for ch in s {
            if ch.isNumber { digits.append(ch) } else if digits.isEmpty { continue } else { break }
        }
        return digits
    }
}
