import Foundation

/// 免看模式：急救现场手忙脚乱，**没人有时间读一段字**。
/// 把方案变成可以听的三段话：先说做什么，再说谁做什么，最后说别做什么。
struct LiftBrief {
    let plan: MovePlan

    var speechText: String {
        var sentences: [String] = []
        sentences.append(headline)
        sentences.append("怎么做：" + plan.steps.joined(separator: "。"))
        sentences.append("分工：" + plan.people.map(\.rawValue).joined(separator: "。"))
        sentences.append("千万不要：" + plan.doNot.joined(separator: "。"))
        return sentences.joined(separator: " ")
    }

    private var headline: String {
        plan.hasEnoughPeople ? "人够了，现在开始。" : "先别抬，去叫人，先清通道。"
    }

    /// 只念最要紧的三句：现场噪音大、耳朵也未必听得清
    var urgentSpeech: String {
        [headline, plan.steps.first ?? "", plan.doNot.first ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// 搬运计时。现场没人记得住过了多久，
/// 但"从开始搬到抬上车用了 6 分钟"这条数据对医生判断失血与休克很有用。
struct MoveTimer {
    private(set) var startedAt: Date?
    private(set) var finishedAt: Date?

    var isRunning: Bool { startedAt != nil && finishedAt == nil }

    mutating func start(at date: Date = Date()) {
        startedAt = date
        finishedAt = nil
    }

    mutating func finish(at date: Date = Date()) -> TimeInterval? {
        guard let startedAt else { return nil }
        finishedAt = date
        return date.timeIntervalSince(startedAt)
    }

    mutating func reset() {
        startedAt = nil
        finishedAt = nil
    }

    var elapsed: TimeInterval? {
        guard let startedAt else { return nil }
        return (finishedAt ?? Date()).timeIntervalSince(startedAt)
    }

    /// 交给医生时的一句话
    func report() -> String {
        guard let startedAt else { return "未记录搬运时间" }
        let seconds = Int(elapsed ?? 0)
        let minutes = seconds / 60
        let rest = seconds % 60
        return "从开始搬动到结束共 \(minutes) 分 \(rest) 秒。开始时间 \(startedAt.formatted(date: .omitted, time: .shortened))。"
    }
}
