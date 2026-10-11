import Foundation
import SwiftUI

@MainActor
final class BridgeViewModel: ObservableObject {
    enum Stage: Equatable {
        case idle, listening, confirming, card
    }

    @Published var patient = VisitCard.PatientProfile()
    @Published var stage: Stage = .idle
    @Published var transcript: String = ""
    @Published var segments: [NormalizedSegment] = []
    @Published var spots: [BodySpot] = []
    @Published var fragments: [UnmatchedFragment] = []
    @Published var onsets: [TimelineExtractor.Onset] = []
    @Published var errorMessage: String?
    @Published var isScriptedDemo = false
    @Published var history: [VisitCard] = []
    /// 语料变更计数：驱动症状卡等界面重建
    @Published private(set) var corpusTick = 0

    /// 内置词库 + 社区共建词库
    let store = TerminologyStore()
    private let scripted = ScriptedSpeechRecognizer()
    private let interpreter: Interpreting = RuleBasedInterpreter()
    private var normalizer: DialectNormalizer {
        DialectNormalizer(region: patient.dialect, corpus: store.all)
    }

    init() {
        store.load()
    }

    func corpusDidChange() { corpusTick += 1 }

    // MARK: - 演示脚本（评委一键跑通）

    @Published private(set) var demoIndex = 0

    /// 按下"一键演示"：加载一个**完整画像**（方言、年龄、台词、指认位置），
    /// 不是一个孤立的句子——评委看到的是一个人，不是一条数据。
    func startDemo() {
        isScriptedDemo = true
        let scenario = DemoScenarios.all[demoIndex % DemoScenarios.all.count]
        patient.nickname = scenario.persona
        patient.age = scenario.age
        patient.dialect = scenario.dialect
        spots = scenario.spots
        scripted.enqueue([scenario.line])
        listen()
    }

    func nextDemo() {
        demoIndex += 1
        reset()
        startDemo()
    }

    func toggleDemoMode(_ on: Bool) {
        isScriptedDemo = on
    }

    // MARK: - 语音录入

    func listen() {
        errorMessage = nil
        stage = .listening
        let recognizer: SpeechRecognizing = isScriptedDemo
            ? scripted
            : DialectSpeechRecognizer(localeIdentifier: localeFor(patient.dialect))
        recognizer.transcribe { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let text):
                self.ingest(text)
            case .failure(let error):
                self.stage = .idle
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// 所有输入（语音、打字、家属代录）走同一条归一化流水线——
    /// 没有麦克风权限、老人说不清、家属在旁边帮忙，都不该是死路。
    func ingest(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        transcript = trimmed
        segments = normalizer.normalize(trimmed)
        fragments = interpreter.interpret(trimmed,
                                          alreadyMatched: segments,
                                          region: patient.dialect,
                                          corpus: store.all)
        onsets = TimelineExtractor().extract(from: trimmed)
        stage = segments.isEmpty ? .idle : .confirming
        errorMessage = segments.isEmpty
            ? "这句话没能对应到症状词。可以让家属帮忙打几个字，或直接点下面的症状卡。"
            : nil
    }

    func confirm() {
        guard !segments.isEmpty || !spots.isEmpty else { return }
        buildCard()
        stage = .card
    }

    func toggle(_ term: MedicalTerm) {
        if let idx = segments.firstIndex(where: { $0.term.id == term.id }) {
            segments.remove(at: idx)
        } else {
            segments.append(.init(source: term.standard, standard: term.standard, term: term, confidence: 1))
        }
        if segments.isEmpty { stage = .idle }
    }

    func isSelected(_ term: MedicalTerm) -> Bool {
        segments.contains { $0.term.id == term.id }
    }

    func remove(_ segment: NormalizedSegment) {
        segments.removeAll { $0.id == segment.id }
        if segments.isEmpty { stage = .idle }
    }

    func buildCard() {
        let pathway = CarePathway.derive(from: segments, spots: spots, age: patient.age)
        let card = VisitCard(id: UUID(), createdAt: Date(), patient: patient,
                            reportedSymptoms: segments, bodySpots: spots,
                            onsets: onsets.map(\.description),
                            unresolved: fragments.map(\.text),
                            pathway: pathway)
        history.insert(card, at: 0)
        if history.count > 20 { history.removeLast() }
    }

    func reset() {
        stage = .idle
        transcript = ""
        segments = []
        spots = []
        fragments = []
        onsets = []
        errorMessage = nil
    }

    /// 方言 → Speech 框架 locale
    func localeFor(_ region: DialectRegion) -> String {
        switch region {
        case .putonghua: "zh-CN"
        case .wu: "zh-CN"        // 吴语无独立 locale，退回普通话识别 + 本地词表
        case .cantonese: "zh-HK"
        case .minnan: "zh-Hant-TW"
        case .sichuan: "zh-CN"
        case .minyue: "zh-CN"
        }
    }
}
