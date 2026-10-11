import Foundation

/// 联系人分级：先近后远，先静默后惊动。
enum ContactTier: String, CaseIterable, Codable {
    case neighbor = "同住家人或邻居"
    case family = "子女"
    case emergency = "急救中心"
}

struct EmergencyContact: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var relation: String
    var phone: String
    var tier: ContactTier
    /// 是否有权先联系——避免邻里之间因误报产生矛盾
    var preAuthorized: Bool

    init(id: UUID = UUID(), name: String, relation: String, phone: String, tier: ContactTier, preAuthorized: Bool = true) {
        self.id = id
        self.name = name
        self.relation = relation
        self.phone = phone
        self.tier = tier
        self.preAuthorized = preAuthorized
    }
}

struct EscalationStep: Identifiable, Hashable {
    let id: Int
    let tier: ContactTier
    let target: String
    let waitSeconds: Double
    let channel: String
    let message: String
}

struct EscalationPlan {
    let steps: [EscalationStep]
    let totalWaitSeconds: Double
}

/// 静默升级：这一级没人应答，才惊动下一级。
struct EscalationPlanner {
    var waitPerTier: Double = 30
    /// 夜里先发短信、10 秒后再打电话，比直接打电话更体面
    var messageFirst: Bool = true

    func plan(contacts: [EmergencyContact], verdict: FallVerdict, personName: String, location: String) -> EscalationPlan {
        var steps: [EscalationStep] = []
        var index = 1
        var totalWait: Double = 0

        let ordered = contacts.sorted { $0.tier.rawValue < $1.tier.rawValue }
        for contact in ordered {
            guard contact.preAuthorized else { continue }
            let message = message(for: contact, verdict: verdict, personName: personName, location: location)
            let channel = messageFirst ? "先发短信，10 秒后拨打电话" : "直接拨打电话"
            let target = "\(contact.name)（\(contact.relation)）"
            let step = EscalationStep(id: index, tier: contact.tier, target: target, waitSeconds: waitPerTier, channel: channel, message: message)
            steps.append(step)
            totalWait += waitPerTier
            index += 1
        }
        return EscalationPlan(steps: steps, totalWaitSeconds: totalWait)
    }

    func message(for contact: EmergencyContact, verdict: FallVerdict, personName: String, location: String) -> String {
        let head: String
        switch verdict.phase {
        case .needHelp: head = "【紧急】\(personName)疑似跌倒后无法起身"
        case .recovered: head = "【提示】\(personName)刚才疑似跌倒，已自行起身"
        case .idle: head = "【提示】\(personName)的设备检测到一次冲击"
        }
        let impact = "冲击 \(String(format: "%.1f", verdict.impactG))g，撞击后静止 \(Int(verdict.stillnessSeconds)) 秒。"
        return [head, impact, "位置：\(location)", "如果 10 分钟内没人回应，请直接上门或拨打 120。"].joined(separator: "\n")
    }
}
