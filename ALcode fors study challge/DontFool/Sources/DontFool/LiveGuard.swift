import Foundation

/// 风险等级
enum RiskLevel: Int, Comparable, Codable {
    case none = 0
    case suspicious = 1   // 出现了单个特征，先别挂，也先别信
    case alerting = 2     // 特征组合成立，该提示了
    case urgent = 3       // 正在要求转账 / 共享屏幕，立刻打断

    static func < (l: RiskLevel, r: RiskLevel) -> Bool { l.rawValue < r.rawValue }

    var label: String {
        switch self {
        case .none: "没有发现异常"
        case .suspicious: "有点可疑"
        case .alerting: "很可能是诈骗"
        case .urgent: "⚠️ 正在被骗，立刻挂断"
        }
    }

    /// 不同等级对应不同的触觉节奏——不能等到最后才响
    var hapticName: String {
        switch self {
        case .none: "不提醒"
        case .suspicious: "轻-短（一下）"
        case .alerting: "短-短-停（提醒你当心）"
        case .urgent: "长-长-长（必须停）"
        }
    }
}

struct FraudAssessment {
    let level: RiskLevel
    let matchedScripts: [FraudScript]
    /// 命中的具体话术片段，让人能看懂为什么
    let evidence: [String]
    let actions: [String]
}

/// 实时话术检测。核心原则：
/// **单个词不报警**。老人日常通话里出现"退款""公安"太常见了，
/// 只有套路组合成立才提示，否则一天误报十几次，这个 App 就废了。
struct LiveGuard {
    /// 出现可疑特征时的门槛
    var suspiciousScore = 1
    /// 提示级别所需的组合强度
    var alertingScore = 3
    /// 出现转账或屏幕共享时直接跳到最高级，不等组合
    var immediateTriggers: Set<String> = ["安全账户", "屏幕共享", "共享屏幕", "转账", "打款", "验证码", "银行卡号"]

    func assess(_ text: String) -> FraudAssessment {
        let normalized = text.lowercased()
        var score = 0
        var scripts: [FraudScript] = []
        var evidence: [String] = []
        var urgentHit = false

        for script in FraudScript.allCases {
            let hits = script.triggers.filter { normalized.contains($0.lowercased()) }
            if !hits.isEmpty {
                scripts.append(script)
                evidence.append("\(script.rawValue)：命中「\(hits.joined(separator: "、"))」")
                score += hits.count
            }
        }

        for word in immediateTriggers where normalized.contains(word.lowercased()) {
            urgentHit = true
            evidence.append("要求涉及「\(word)」")
        }

        // 保密要求是所有套路的公共结构，单独计分
        for word in ["不要告诉", "先别挂", "保密", "不许挂电话", "按我说的做"] where normalized.contains(word) {
            score += 1
            evidence.append("要求保密或服从指令：「\(word)」")
        }

        let level: RiskLevel
        if urgentHit {
            level = .urgent
        } else if score >= alertingScore {
            level = .alerting
        } else if score >= suspiciousScore {
            level = .suspicious
        } else {
            level = .none
        }

        return FraudAssessment(
            level: level,
            matchedScripts: scripts,
            evidence: evidence,
            actions: scripts.isEmpty ? [] : Array(Set(scripts.map(\.doThis))).sorted()
        )
    }

    /// 滑动窗口检测：只判断"最近这一段话"，而不是整通电话。
    /// 因为骗子往往先聊二十分钟家常，才进入正题。
    struct RollingWindow {
        let limit: Int
        private var buffer: [String] = []

        init(limit: Int = 80) { self.limit = limit }

        mutating func push(_ utterance: String) {
            buffer.append(utterance)
            if buffer.count > limit { buffer.removeFirst() }
        }

        var text: String { buffer.joined(separator: "，") }
    }
}
