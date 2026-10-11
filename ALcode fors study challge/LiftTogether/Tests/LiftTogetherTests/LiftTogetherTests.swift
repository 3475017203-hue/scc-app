import XCTest
@testable import LiftTogether

final class RouteScorerTests: XCTestCase {
    private let scorer = RouteScorer()

    func testSteepNarrowStairsAreFatalForSpineInjury() {
        let stairs = TerrainSegment(name: "窄楼梯", length: 6, slopePercent: 0, steps: 12, narrowestCm: 68)
        XCTAssertNil(scorer.score(stairs, for: .spineSuspected))
    }

    func testSameStairsAreFineForMinorInjury() {
        let stairs = TerrainSegment(name: "窄楼梯", length: 6, slopePercent: 0, steps: 12, narrowestCm: 68)
        XCTAssertNotNil(scorer.score(stairs, for: .minor))
    }

    func testMudSlopeIsFatalForLifeThreatening() {
        let bad = TerrainSegment(name: "泥坡", length: 8, slopePercent: 18, narrowestCm: 90, surface: .mud)
        XCTAssertNil(scorer.score(bad, for: .spineSuspected))
        XCTAssertNotNil(scorer.score(bad, for: .minor))
    }

    func testSidewaysNarrowPathRejectedForHipFracture() {
        let gap = TerrainSegment(name: "窄巷", length: 5, slopePercent: 0, narrowestCm: 65, requiresSideways: true)
        XCTAssertNil(scorer.score(gap, for: .hipFracture))
    }

    /// 关键行为：不是找最短，是找**伤情允许的**最短。
    func testPrefersLongerSafeRouteOverShorterRiskyOne() {
        let risky = TerrainSegment(name: "侧门小路", length: 8, slopePercent: 18, narrowestCm: 90, surface: .mud)
        let safe = TerrainSegment(name: "正门缓坡", length: 22, slopePercent: 12, narrowestCm: 200, surface: .grass)
        let choice = scorer.bestRoute(from: [risky, safe], for: .spineSuspected)
        XCTAssertEqual(choice?.segment.name, "正门缓坡")
        XCTAssertEqual(choice?.rejectedCount, 1)
    }

    func testNoSafeRouteYieldsNil() {
        let bad1 = TerrainSegment(name: "楼梯", length: 6, steps: 12, narrowestCm: 68)
        let bad2 = TerrainSegment(name: "泥坡", length: 8, slopePercent: 18, narrowestCm: 90, surface: .mud)
        XCTAssertNil(scorer.bestRoute(from: [bad1, bad2], for: .spineSuspected))
    }

    func testSteeperRouteScoresLowerOnEqualConditions() {
        let gentle = TerrainSegment(name: "缓", length: 20, slopePercent: 4)
        let steep = TerrainSegment(name: "陡", length: 20, slopePercent: 16)
        XCTAssertGreaterThan(scorer.score(gentle, for: .minor)!, scorer.score(steep, for: .minor)!)
    }
}

final class PlanGeneratorTests: XCTestCase {
    private func plan(_ injury: InjuryCase, _ people: Int, segments: [TerrainSegment] = SampleEnvironment.all) -> MovePlan {
        PlanGenerator().plan(for: injury, segments: segments, availablePeople: people)
    }

    func testNotEnoughPeopleProducesWarning() {
        let p = plan(.spineSuspected, 2)
        XCTAssertFalse(p.hasEnoughPeople)
        XCTAssertTrue(p.headline.contains("先别硬抬"))
    }

    func testSpinePlanAlwaysHasFourRoles() {
        let p = plan(.spineSuspected, 4)
        XCTAssertEqual(p.people.count, 4)
        XCTAssertTrue(p.people.contains(.headHolder))
    }

    func testHipFractureForbidsCarrying() {
        XCTAssertTrue(plan(.hipFracture, 3).doNot.contains("禁止背"))
    }

    func testUnconsciousIncludesAirwayReminder() {
        XCTAssertTrue(plan(.unconscious, 3).doNot.contains("禁止喂水喂药"))
    }

    func testEveryInjuryHasWaitingActions() {
        for injury in InjuryCase.allCases {
            XCTAssertFalse(plan(injury, 6).whileWaiting.isEmpty)
            XCTAssertFalse(plan(injury, 6).doNot.isEmpty)
        }
    }

    func testNoRouteYieldsDoNotMoveAdvice() {
        let impossible = [TerrainSegment(name: "窄楼梯", length: 6, steps: 12, narrowestCm: 60)]
        let p = plan(.spineSuspected, 4, segments: impossible)
        XCTAssertNil(p.route)
        XCTAssertTrue(p.headline.contains("先别动"))
    }
}

final class LiftBriefTests: XCTestCase {
    private func samplePlan(_ injury: InjuryCase = .spineSuspected, people: Int = 4) -> MovePlan {
        PlanGenerator().plan(for: injury, segments: SampleEnvironment.all, availablePeople: people)
    }

    /// 人不够时，念出来的第一句必须是"别抬"。
    func testSpeechLeadsWithDoNotLiftWhenShortHanded() {
        let brief = LiftBrief(plan: samplePlan(.spineSuspected, people: 2))
        XCTAssertTrue(brief.speechText.hasPrefix("先别抬"))
    }

    func testSpeechIncludesDoNotList() {
        let brief = LiftBrief(plan: samplePlan())
        XCTAssertTrue(brief.speechText.contains("千万不要"))
        XCTAssertTrue(brief.speechText.contains("禁止扶人坐起"))
    }

    func testUrgentSpeechKeepsOnlyThreeSentences() {
        let brief = LiftBrief(plan: samplePlan())
        XCTAssertLessThan(brief.urgentSpeech.count, brief.speechText.count)
    }
}

final class MoveTimerTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_760_000_000)

    func testElapsedCountsFromStart() {
        var timer = MoveTimer()
        timer.start(at: base)
        let duration = timer.finish(at: base.addingTimeInterval(370))
        XCTAssertEqual(duration, 370)
        XCTAssertFalse(timer.isRunning)
    }

    func testFinishWithoutStartReturnsNil() {
        var timer = MoveTimer()
        XCTAssertNil(timer.finish(at: base))
    }

    func testReportMentionsDuration() {
        var timer = MoveTimer()
        timer.start(at: base)
        _ = timer.finish(at: base.addingTimeInterval(65))
        XCTAssertTrue(timer.report().contains("1 分 5 秒"))
    }

    func testResetClearsEverything() {
        var timer = MoveTimer()
        timer.start(at: base)
        timer.reset()
        XCTAssertNil(timer.elapsed)
        XCTAssertTrue(timer.report().contains("未记录"))
    }
}
