import Foundation

struct NormalizedSegment: Identifiable, Hashable, Codable {
    let id: UUID
    let source: String
    let standard: String
    let term: MedicalTerm
    /// 0…1，来自模糊匹配的相似度
    let confidence: Double
    /// 老人说了"不 / 没有" —— 临床上的**否定**必须被识别，
    /// 否则"没有头晕"会被当成阳性主诉，直接污染分诊与医嘱。
    let isNegated: Bool
    /// 命中的否定词，方便在卡片上原样呈现给医生核对
    let negationCue: String?

    init(id: UUID = UUID(), source: String, standard: String, term: MedicalTerm,
         confidence: Double, isNegated: Bool = false, negationCue: String? = nil) {
        self.id = id
        self.source = source
        self.standard = standard
        self.term = term
        self.confidence = confidence
        self.isNegated = isNegated
        self.negationCue = negationCue
    }
}

/// 方言 → 普通话 归一化。
/// 纯本地、可解释、不联网：先做确定性词表匹配，再对未命中的片段做近音纠错。
struct DialectNormalizer {
    let region: DialectRegion
    let corpus: [MedicalTerm]

    init(region: DialectRegion, corpus: [MedicalTerm] = Terminology.all) {
        self.region = region
        self.corpus = corpus
    }

    /// 把一段口语转写切成若干术语命中。
    func normalize(_ transcript: String) -> [NormalizedSegment] {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        var hits: [NormalizedSegment] = []
        var covered = Set<String>()
        let terms = corpus
            .filter { $0.regions.isEmpty || $0.regions.contains(region) }
            .sorted { $0.colloquialisms.count > $1.colloquialisms.count } // 长词优先，避免"肚子痛"被"肚脐眼疼"切碎

        for term in terms {
            for phrase in term.colloquialisms {
                if let range = text.range(of: phrase), !covered.contains(phrase) {
                    let negation = negation(before: text, upTo: range.lowerBound)
                    hits.append(.init(source: phrase, standard: term.standard, term: term,
                                      confidence: 1.0,
                                      isNegated: negation.cue != nil,
                                      negationCue: negation.cue))
                    covered.insert(phrase)
                }
            }
        }

        // 未命中的残余：近音纠错（例："心口疼"→"心口痛"、错字"哈不动"→"喘不动"）
        let hitTermIDs = Set(hits.map(\.term.id))
        for term in terms where !hitTermIDs.contains(term.id) {
            guard let best = bestCandidate(in: text, phrases: term.colloquialisms), best.similarity < 1 else { continue }
            if best.similarity >= 0.6 {
                hits.append(.init(source: best.phrase, standard: term.standard, term: term,
                                  confidence: best.similarity,
                                  // 模糊命中没有确定的字位，**宁可漏判否定也不误判**，
                                  // 卡片上会提示医生复核。
                                  isNegated: false))
            }
        }

        return hits.sorted { $0.confidence > $1.confidence }
    }

    /// 只看命中点**前 4 个字**找否定词，避免把别处的"不"错配过来。
    /// 语料规模有限时，这种"窄窗口 + 就近否定"是宁可漏判也不能误判的取舍。
    private func negation(before text: String, upTo index: String.Index) -> (cue: String?, window: String) {
        let start = text.index(index, offsetBy: -4, limitedBy: text.startIndex) ?? text.startIndex
        let window = String(text[start..<index])
        guard let cue = NegationCues.all.first(where: { window.hasSuffix($0) }) else { return (nil, window) }
        return (cue, window)
    }

    /// 大声念出"标准说法"，供老人跟读确认。
    func confirmationPhrase(for segment: NormalizedSegment) -> String {
        "您说的是「\(segment.standard)」，对吗？"
    }

    // MARK: - 相似度

    private struct Candidate { let phrase: String; let similarity: Double }

    private func bestCandidate(in text: String, phrases: [String]) -> Candidate? {
        var best: Candidate?
        for phrase in phrases where phrase.count >= 2 {
            let score = bestSlidingSimilarity(text, phrase)
            if best == nil || score > best!.similarity {
                best = Candidate(phrase: phrase, similarity: score)
            }
        }
        return best
    }

    private func bestSlidingSimilarity(_ a: String, _ b: String) -> Double {
        let x = Array(a), y = Array(b)
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        guard x.count >= y.count else { return similarity(Array(y.prefix(x.count)), x) }
        var best = 0.0
        for i in 0...(x.count - y.count) {
            best = max(best, similarity(Array(x[i..<(i + y.count)]), y))
        }
        return best
    }

    /// Dice 二元组相似度 —— 比编辑距离更贴近"听错一个音"的现实。
    private func similarity(_ a: [Character], _ b: [Character]) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let sa = Set(zip(a, a.dropFirst()))
        let sb = Set(zip(b, b.dropFirst()))
        if sa.isEmpty || sb.isEmpty { return a == b ? 1 : 0 }
        let inter = Double(sa.intersection(sb).count)
        return 2 * inter / Double(sa.count + sb.count)
    }
}

enum NegationCues {
    /// 按长度倒序，保证"没有"优先于"有"
    static let all: [String] = [
        "没有", "不很", "未曾", "没什么", "不曾", "不大", "不", "没", "无", "别"
    ].sorted { $0.count > $1.count }
}
