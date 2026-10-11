import XCTest
@testable import DialectBridge

final class NormalizerTests: XCTestCase {
    func testDetectsSichuaneseComplaint() {
        let n = DialectNormalizer(region: .sichuan)
        let hits = n.normalize("这两天心口疼，压得慌，还气不大来")
        XCTAssertTrue(hits.contains { $0.standard.contains("胸闷") })
    }

    func testNoHallucinationOnUnrelatedText() {
        let hits = DialectNormalizer(region: .putonghua).normalize("今天天气不错")
        XCTAssertTrue(hits.isEmpty)
    }

    func testEmergencyPathwayFromChestPain() {
        let n = DialectNormalizer(region: .putonghua)
        let pathway = CarePathway.derive(from: n.normalize("胸口闷得慌"), age: 78)
        XCTAssertEqual(pathway.urgency, .emergency)
        XCTAssertTrue(pathway.advisories.contains { $0.contains("分诊") })
    }

    func testVisitCardMentionsDialectSource() {
        let n = DialectNormalizer(region: .sichuan)
        var p = VisitCard.PatientProfile()
        p.dialect = .sichuan
        let segs = n.normalize("脑壳痛")
        let card = VisitCard(id: UUID(), createdAt: Date(), patient: p,
                             reportedSymptoms: segs, bodySpots: [],
                             onsets: [], unresolved: [],
                             pathway: CarePathway.derive(from: segs, age: 70))
        XCTAssertTrue(card.plainText.contains("脑壳痛"))
        XCTAssertTrue(card.plainText.contains("头痛"))
    }

    // MARK: - 第二轮新增：否定与位置

    func testNegationIsDetected() {
        let hits = DialectNormalizer(region: .putonghua).normalize("就是没有头晕")
        let dizzy = hits.first { $0.standard.contains("头晕") }
        XCTAssertEqual(dizzy?.isNegated, true)
        XCTAssertEqual(dizzy?.negationCue, "没有")
    }

    func testNegatedSymptomDoesNotRaiseUrgency() {
        let n = DialectNormalizer(region: .putonghua)
        let segs = n.normalize("没有胸口闷")
        let pathway = CarePathway.derive(from: segs, age: 70)
        XCTAssertEqual(pathway.urgency, .routine)
        XCTAssertTrue(pathway.advisories.contains { $0.contains("否认") })
    }

    func testBodySpotRaisesUrgencyAndAppearsInCard() {
        let n = DialectNormalizer(region: .putonghua)
        let segs = n.normalize("有点胃疼")
        let spots = [BodySpot(region: .chest, side: .left)]
        let pathway = CarePathway.derive(from: segs, spots: spots, age: 80)
        XCTAssertEqual(pathway.urgency, .urgent)
        XCTAssertTrue(pathway.advisories.contains { $0.contains("胸部") })
    }

    // MARK: - 第三轮新增：兜底与病程

    func testUnmatchedFragmentIsNotDiscarded() {
        let n = DialectNormalizer(region: .putonghua)
        let text = "胸口闷，另外还有点飘"
        let hits = n.normalize(text)
        let fragments = RuleBasedInterpreter().interpret(text, alreadyMatched: hits, region: .putonghua)
        XCTAssertFalse(fragments.isEmpty)
        XCTAssertTrue(fragments.allSatisfy { $0.text.count >= 2 })
    }

    func testFuzzyFallbackSuggestsTermForMisspelling() {
        // 老人把"喘不上气"说成"喘不上汽"——词表外，但兜底引擎应该给出候选
        let fragments = RuleBasedInterpreter().interpret("喘不上汽", alreadyMatched: [], region: .putonghua)
        XCTAssertTrue(fragments.contains { $0.candidates.contains { $0.id == "dyspnea" } })
    }

    func testTimelineExtraction() {
        let onsets = TimelineExtractor().extract(from: "三年前就开始，最近这两天厉害")
        XCTAssertTrue(onsets.contains { $0.description.contains("长期") || $0.description.contains("数日内") })
        XCTAssertTrue(onsets.contains { $0.isAcute == false })
    }

    // MARK: - 第四轮新增：词库共建与家属版

    func testCorpusImporterParsesCommunityLines() throws {
        let raw = """
        # 注释行会被忽略
        胸闷 | 心口闷，压得慌 | 心肺 | 吴语
        耳鸣 | 耳朵里嗡嗡 | 其他
        """
        let drafts = try CorpusImporter.parse(raw)
        XCTAssertEqual(drafts.count, 2)
        XCTAssertEqual(drafts[0].colloquialisms, ["心口闷", "压得慌"])
        XCTAssertEqual(drafts[0].category, .cardiopulmonary)
        XCTAssertEqual(drafts[0].regions, [.wu])
        XCTAssertEqual(drafts[1].regions, [])
    }

    func testCorpusImporterRejectsIncompleteLine() {
        XCTAssertThrowsError(try CorpusImporter.parse("胸闷"))
        XCTAssertThrowsError(try CorpusImporter.parse("   "))
    }

    func testExportedCorpusCanBeReimported() throws {
        let exported = CorpusImporter.export(Array(Terminology.all.prefix(3)))
        let drafts = try CorpusImporter.parse(exported)
        XCTAssertEqual(drafts.count, 3)
    }

    @MainActor
    func testCaregiverScriptMentionsDepartment() {
        let n = DialectNormalizer(region: .wu)
        let segs = n.normalize("心口闷")
        let card = VisitCard(id: UUID(), createdAt: Date(), patient: .init(),
                             reportedSymptoms: segs, bodySpots: [], onsets: [], unresolved: [],
                             pathway: CarePathway.derive(from: segs, age: 80))
        XCTAssertTrue(SpeechCoach().script(for: card, audience: .family).contains(card.pathway.department))
        XCTAssertTrue(SpeechCoach().script(for: card, audience: .doctor).contains("80岁"))
    }

    // MARK: - 第五轮新增：社区词库生效

    @MainActor
    func testCommunityCorpusTakesEffect() throws {
        let store = TerminologyStore()
        store.reset()
        let drafts = try CorpusImporter.parse("胸口发紧 | 心头像压块石头 | 心肺 | 通用")
        store.importDrafts(drafts)
        XCTAssertEqual(store.totalCount, Terminology.all.count)
        store.approve(drafts[0])
        XCTAssertEqual(store.totalCount, Terminology.all.count + 1)

        // 内置词库里没有这句话，导入后必须能识别出来
        let n = DialectNormalizer(region: .putonghua, corpus: store.all)
        let hits = n.normalize("这两天心头像压块石头")
        XCTAssertTrue(hits.contains { $0.standard.contains("胸闷") })
        store.reset()
    }

    @MainActor
    func testImportMergesInsteadOfDuplicating() throws {
        let store = TerminologyStore()
        store.reset()
        store.importDrafts(try CorpusImporter.parse("胸闷 / 胸痛 | 心头堵 | 心肺"))
        store.approveAll()
        store.importDrafts(try CorpusImporter.parse("胸闷 / 胸痛 | 胸口发闷 | 心肺"))
        let second = store.approveAll()
        XCTAssertEqual(store.communityTerms.count, 1)
        XCTAssertEqual(store.communityTerms.first?.colloquialisms.count, 2)
        XCTAssertEqual(second, 1)
        store.reset()
    }

    /// 没有医生签字的说法，不得进入词库——这是权威背书的最低限度。
    @MainActor
    func testUnapprovedDraftDoesNotAffectNormalization() throws {
        let store = TerminologyStore()
        store.reset()
        let drafts = try CorpusImporter.parse("胸口发紧 | 心头像压块石头 | 心肺")
        store.importDrafts(drafts)
        let n = DialectNormalizer(region: .putonghua, corpus: store.all)
        XCTAssertTrue(n.normalize("这两天心头像压块石头").isEmpty)
        XCTAssertEqual(store.pendingDrafts.count, 1)
        store.reset()
    }

    @MainActor
    func testRejectedDraftLeavesCorpusUntouched() throws {
        let store = TerminologyStore()
        store.reset()
        let drafts = try CorpusImporter.parse("头晕 | 晕巴拉 | 神经")
        store.importDrafts(drafts)
        store.reject(drafts[0])
        XCTAssertTrue(store.pendingDrafts.isEmpty)
        XCTAssertEqual(store.totalCount, Terminology.all.count)
        store.reset()
    }

    // MARK: - 第六轮新增：打字/家属代录

    @MainActor
    func testTypedInputUsesSamePipelineAsSpeech() {
        let vm = BridgeViewModel()
        vm.ingest("心口闷，压得慌")
        XCTAssertEqual(vm.stage, .confirming)
        XCTAssertFalse(vm.segments.isEmpty)
        XCTAssertTrue(vm.transcript.contains("压得慌"))
    }

    @MainActor
    func testTypedInputRespectsCommunityCorpus() throws {
        let vm = BridgeViewModel()
        vm.store.reset()
        vm.store.importDrafts(try CorpusImporter.parse("胸口发紧 | 心头像压块石头 | 心肺"))
        vm.store.approveAll()
        vm.ingest("这两天心头像压块石头")
        XCTAssertTrue(vm.segments.contains { $0.standard.contains("胸闷") })
        vm.store.reset()
    }
}
