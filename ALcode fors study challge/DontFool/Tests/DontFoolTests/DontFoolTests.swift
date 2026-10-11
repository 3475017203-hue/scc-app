import XCTest
@testable import DontFool

final class LiveGuardTests: XCTestCase {
    private let engine = LiveGuard()

    /// 最关键的测试：正常通话里出现"客服""退款"不能报警。
    /// 老人一天要说很多句带这些词的话，误报一次这个 App 就废了。
    func testNormalCallStaysQuiet() {
        let text = DemoScenarios.safeCall.joined(separator: "，")
        XCTAssertEqual(engine.assess(text).level, .none)
    }

    func testFamilyAndSafeTalkStaysQuiet() {
        let text = "孩子我明天回家吃饭，冰箱里有菜，你记得早点睡"
        XCTAssertEqual(engine.assess(text).level, .none)
    }

    func testSingleFeatureOnlySuspicious() {
        let result = engine.assess("您会员要扣费了")
        XCTAssertEqual(result.level, .suspicious)
    }

    func testCombinationEscalatesToAlerting() {
        let text = "我是公安局的，你涉嫌洗钱，现在要资金清查"
        let result = engine.assess(text)
        XCTAssertGreaterThanOrEqual(result.level, .alerting)
        XCTAssertTrue(result.matchedScripts.contains(.impersonationPolice))
    }

    /// 出现转账 / 屏幕共享 / 验证码这类要求时，立刻到最高级，不等组合。
    func testTransferRequestIsUrgentImmediately() {
        let result = engine.assess("请你把钱转到安全账户")
        XCTAssertEqual(result.level, .urgent)
        XCTAssertFalse(result.actions.isEmpty)
    }

    func testScreenSharingIsUrgentImmediately() {
        XCTAssertEqual(engine.assess("我们开启屏幕共享，我帮你操作").level, .urgent)
    }

    func testEvidenceIsAlwaysExplainable() {
        let result = engine.assess("我是公安局的，你涉嫌洗钱")
        XCTAssertFalse(result.evidence.isEmpty)
    }

    func testEveryScriptProvidesAnAction() {
        for script in FraudScript.allCases {
            XCTAssertFalse(script.doThis.isEmpty)
            XCTAssertFalse(script.whyDangerous.isEmpty)
            XCTAssertFalse(script.triggers.isEmpty)
        }
    }
}

final class RollingWindowTests: XCTestCase {
    /// 骗子往往先聊二十分钟家常才进正题，所以要滚动窗口而不是整通电话。
    func testWindowDropsOldTurns() {
        var window = LiveGuard.RollingWindow(limit: 3)
        for i in 0..<10 { window.push("第\(i)句家常话") }
        let text = window.text
        XCTAssertFalse(text.contains("第0句"))
        XCTAssertTrue(text.contains("第9句"))
    }

    func testWindowKeepsRecentFraudAfterLongChat() {
        let engine = LiveGuard()
        var window = LiveGuard.RollingWindow(limit: 3)
        for i in 0..<8 { window.push("今天天气不错，菜多少钱") }
        window.push("我是公安局的")
        window.push("你涉嫌洗钱")
        window.push("请转到安全账户")
        XCTAssertEqual(engine.assess(window.text).level, .urgent)
    }
}

@MainActor
final class GuardViewModelTests: XCTestCase {
    func testSafeScenarioStaysGreen() {
        let vm = GuardViewModel()
        vm.replay(DemoScenarios.safeCall)
        XCTAssertEqual(vm.current?.level, .none)
    }

    func testUrgentScenarioReachesRed() {
        let vm = GuardViewModel()
        vm.replay(DemoScenarios.urgentCall)
        XCTAssertEqual(vm.current?.level, .urgent)
        XCTAssertFalse(vm.history.isEmpty)
    }

    func testResetClearsEverything() {
        let vm = GuardViewModel()
        vm.replay(DemoScenarios.urgentCall)
        vm.reset()
        XCTAssertNil(vm.current)
        XCTAssertTrue(vm.history.isEmpty)
    }
}

@MainActor
final class ScamCorpusTests: XCTestCase {
    private let story = ScamStory(
        transcript: "我是公安局的，你儿子涉嫌洗钱，这件事不要告诉任何人",
        experience: "差点转了两万块",
        claimedRole: "冒充警察",
        byline: "李阿姨")

    func testTriggersExtractedFromRealStory() {
        let hits = ScamCorpus().extractTriggers(from: story)
        XCTAssertTrue(hits.contains("涉嫌"))
        XCTAssertTrue(hits.contains("不要告诉"))
    }

    /// 没签字就不入库——受害者的话也不能直接变成判定依据。
    func testUnapprovedStoryStaysPending() {
        let corpus = ScamCorpus()
        corpus.submit(story)
        XCTAssertEqual(corpus.pending.count, 1)
        XCTAssertTrue(corpus.approved.isEmpty)
    }

    func testOrdinaryPersonCannotApprove() {
        let corpus = ScamCorpus()
        corpus.submit(story)
        XCTAssertTrue(corpus.approve(story, by: "隔壁老王").isEmpty)
        XCTAssertNotNil(corpus.storageError)
        XCTAssertEqual(corpus.pending.count, 1)
    }

    func testOfficerApprovalAddsToCorpus() {
        let corpus = ScamCorpus()
        corpus.submit(story)
        XCTAssertFalse(corpus.approve(story, by: "社区民警小张").isEmpty)
        XCTAssertTrue(corpus.pending.isEmpty)
        XCTAssertEqual(corpus.approved.count, 1)
    }

    /// 个人信息不进词库：只抽结构词。
    func testNoPersonalInfoLeaksIntoCorpus() {
        let named = ScamStory(transcript: "我是张伟，工号 00123，转账到我 6222021234567890",
                             experience: "", claimedRole: "冒充客服", byline: "")
        let hits = ScamCorpus().extractTriggers(from: named)
        XCTAssertFalse(hits.contains { $0.contains("6222") })
        XCTAssertFalse(hits.contains { $0.contains("张伟") })
    }
}
