import Foundation

/// 归一化失败时的兜底：把"没听懂的部分"变成**可确认的猜测**，而不是丢掉。
struct UnmatchedFragment: Identifiable, Hashable {
    let id = UUID()
    let text: String
    /// 规则引擎给出的候选（按置信度降序）
    let candidates: [MedicalTerm]
    let confidence: Double
    let note: String

    var display: String {
        candidates.isEmpty ? text : "「\(text)」可能是：\(candidates.map(\.standard).joined(separator: " / "))"
    }
}

protocol Interpreting: AnyObject {
    var engineName: String { get }
    func interpret(_ text: String, alreadyMatched: [NormalizedSegment],
                   region: DialectRegion, corpus: [MedicalTerm]) -> [UnmatchedFragment]
}

/// 纯规则兜底：永远可用、可解释、离线。
/// 真机上有 Foundation Models 时会被更聪明的实现替换，但这一层不删——
/// 它保证"AI 不可用 / 离线 / 老人设备跑不动"时产品仍然完整。
final class RuleBasedInterpreter: Interpreting {
    var engineName: String { "本地规则兜底" }

    func interpret(_ text: String,
                  alreadyMatched: [NormalizedSegment],
                  region: DialectRegion,
                  corpus: [MedicalTerm] = Terminology.all) -> [UnmatchedFragment] {
        var residual = text
        for hit in alreadyMatched {
            residual = residual.replacingOccurrences(of: hit.source, with: " ")
        }

        return residual
            .components(separatedBy: CharacterSet(charactersIn: "，。！？、,.!? \n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 2 }
            .compactMap { fragment in
                let scored = corpus
                    .filter { $0.regions.isEmpty || $0.regions.contains(region) }
                    .compactMap { term -> (MedicalTerm, Double)? in
                        let best = term.colloquialisms
                            .map { Dice.similarity($0, fragment) }
                            .max() ?? 0
                        return best > 0.34 ? (term, best) : nil
                    }
                    .sorted { $0.1 > $1.1 }

                guard let top = scored.first else {
                    return UnmatchedFragment(text: fragment, candidates: [], confidence: 0,
                                             note: "词库里没有相近的说法，建议改用下面的症状卡点选，或补充到词库。")
                }
                let candidates = Array(scored.prefix(2).map(\.0))
                return UnmatchedFragment(
                    text: fragment,
                    candidates: candidates,
                    confidence: top.1,
                    note: top.1 >= 0.6
                        ? "听上去很像，点一下确认即可。"
                        : "不太确定，请老人自己确认：下面哪个更像？"
                )
            }
    }
}

enum Dice {
    /// 归一化器与兜底引擎共用同一套相似度，保证两条路径的行为可解释、一致。
    static func similarity(_ a: String, _ b: String) -> Double {
        let x = Array(a), y = Array(b)
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        if x.count < y.count { return similarity(y, a) }
        var best = 0.0
        for i in 0...(x.count - y.count) {
            best = max(best, bigram(Array(x[i..<(i + y.count)]), y))
        }
        return best
    }

    private static func bigram(_ a: [Character], _ b: [Character]) -> Double {
        guard a.count >= 2, b.count >= 2 else { return a == b ? 1 : 0 }
        let sa = Set(zip(a, a.dropFirst()))
        let sb = Set(zip(b, b.dropFirst()))
        let inter = Double(sa.intersection(sb).count)
        return 2 * inter / Double(sa.count + sb.count)
    }
}

/// 病程抽取。"三天了""昨天晚上"对诊断价值极高，但老人几乎不会主动说"起病三天前"。
struct TimelineExtractor {
    struct Onset: Hashable {
        let raw: String
        let description: String
        let isAcute: Bool
    }

    private static let numberWords: [String: Int] = [
        "半": 1, "一": 1, "两": 2, "二": 2, "三": 3, "四": 4, "五": 5,
        "六": 6, "七": 7, "八": 8, "九": 9, "十": 10, "昨天": 1, "前天": 2,
        "今天": 0, "早上": 0, "夜里": 1
    ]

    func extract(from text: String) -> [Onset] {
        var results: [Onset] = []
        for (word, days) in TimelineExtractor.numberWords where text.contains(word + "前") {
            results.append(Onset(raw: word + "前",
                                 description: "约 \(days) 天前开始",
                                 isAcute: days <= 1))
        }
        for word in ["这几天", "这两天", "这几天了", "好几天"] where text.contains(word) {
            results.append(Onset(raw: word, description: "数日内发作", isAcute: false))
        }
        if text.contains("老毛病") || text.contains("一直有") || text.contains("很多年") {
            results.append(Onset(raw: "长期", description: "长期反复", isAcute: false))
        }
        if text.contains("刚才") || text.contains("突然") {
            results.append(Onset(raw: "突发", description: "突发（数小时内）", isAcute: true))
        }
        return results
    }
}
