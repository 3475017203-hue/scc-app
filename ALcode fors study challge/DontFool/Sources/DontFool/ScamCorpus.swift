import Foundation

/// 一条来自受害者的真实经历。
/// **被骗过的人是这个作品最好的语料来源**——
/// 官方的黑名单永远追不上新套路，而亲历者记得每一句话。
struct ScamStory: Identifiable, Codable, Hashable {
    let id: UUID
    /// 原话转写，尽量保留骗子的原句
    var transcript: String
    /// 老人自己描述的经过
    var experience: String
    /// 老人自称被冒充的身份
    var claimedRole: String
    var byline: String
    var createdAt: Date

    init(id: UUID = UUID(), transcript: String, experience: String,
         claimedRole: String, byline: String, createdAt: Date = Date()) {
        self.id = id
        self.transcript = transcript
        self.experience = experience
        self.claimedRole = claimedRole
        self.byline = byline
        self.createdAt = createdAt
    }
}

/// 共建话术库：录入 → 待审核 → 生效。
/// 审核要两把钥匙：**社区民警或反诈人员签字**，受害者原话直接进入语料。
@MainActor
final class ScamCorpus: ObservableObject {
    @Published private(set) var pending: [ScamStory] = []
    @Published private(set) var approved: [ScamStory] = []
    @Published private(set) var storageError: String?

    private let filename = "scam-stories.json"

    /// 从真实经历里自动抽出的新触发短语。
    /// 只抽取**结构词**（要求保密、要求转账、提到公检法），
    /// 不把姓名、地址这类个人信息写进词库。
    func extractTriggers(from story: ScamStory) -> [String] {
        let text = story.transcript.lowercased()
        var hits: [String] = []
        for script in FraudScript.allCases {
            for trigger in script.triggers where text.contains(trigger.lowercased()) {
                hits.append(trigger)
            }
        }
        for extra in ["不要告诉", "先别挂", "保密", "按我说的做", "我是受上面指派"] where text.contains(extra) {
            hits.append(extra)
        }
        return Array(Set(hits)).sorted()
    }

    func submit(_ story: ScamStory) {
        pending.append(story)
        persist()
    }

    @discardableResult
    func approve(_ story: ScamStory, by reviewer: String) -> [String] {
        guard reviewer.contains("警") || reviewer.contains("反诈") || reviewer.contains("社区") else {
            storageError = "只有社区民警、反诈人员或社区工作者才能签字。"
            return []
        }
        pending.removeAll { $0.id == story.id }
        approved.append(story)
        persist()
        return extractTriggers(from: story)
    }

    func reject(_ story: ScamStory) {
        pending.removeAll { $0.id == story.id }
        persist()
    }

    var corpusSize: Int {
        FraudScript.allCases.reduce(0) { $0 + $1.triggers.count } + approved.reduce(0) { $0 + extractTriggers(from: $1).count }
    }

    // MARK: - 持久化（本地，绝不联网）

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent(filename)
    }

    private func persist() {
        do {
            struct Payload: Codable { let pending: [ScamStory]; let approved: [ScamStory] }
            let data = try JSONEncoder().encode(Payload(pending: pending, approved: approved))
            try data.write(to: fileURL, options: .atomic)
            storageError = nil
        } catch {
            storageError = "本机保存失败：\(error.localizedDescription)"
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            struct Payload: Codable { let pending: [ScamStory]; let approved: [ScamStory] }
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            pending = payload.pending
            approved = payload.approved
            storageError = nil
        } catch {
            storageError = "本机话术库读取失败：\(error.localizedDescription)"
        }
    }
}
