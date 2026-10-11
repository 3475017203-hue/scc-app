import Foundation

/// 语音问询的抽象：先问一句，确认没人应答再升级。
/// 这一步是"静默升级"的灵魂——
/// 它把一串闹钟，变成了一次**有人负责的等待**。
protocol VoiceChecking: AnyObject {
    func ask(_ question: String, completion: @escaping (Bool) -> Void)
}

final class ScriptedVoiceCheck: VoiceChecking {
    private var queue: [Bool] = []
    private let delay: Double

    init(delay: Double = 1.5) { self.delay = delay }

    /// true = 有回应；false = 无回应
    func enqueue(_ responses: [Bool]) { queue.append(contentsOf: responses) }

    func ask(_ question: String, completion: @escaping (Bool) -> Void) {
        let responded = queue.isEmpty ? false : queue.removeFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { completion(responded) }
    }
}

/// 问询的措辞是精心挑过的：
/// 不问「你摔了吗」（他可能摔了，也可能只是手机掉了），
/// 只问「你能回我一句吗」——要的是回应，不是答案。
enum VoicePrompt {
    static let questions = [
        "我听到动静了，你还好吗？能回我一句吗？",
        "不说话的话我就要叫人了，你能动一下吗？",
        "我现在准备联系你女儿了，真的没事吗？"
    ]
}

/// 三次问询的判定规则：任一次有回应即中止升级。
struct VoiceCheckFlow {
    let questions: [String]

    /// 返回 true 表示**需要升级**
    func needsEscalation(responses: [Bool]) -> Bool {
        !responses.contains(true)
    }

    var totalQuestions: Int { questions.count }
}
