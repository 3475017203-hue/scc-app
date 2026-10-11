import XCTest
@testable import MealTrace

private let cal = Calendar(identifier: .gregorian)

private func day(_ m: Int, _ d: Int) -> Date {
    cal.date(from: DateComponents(year: 2026, month: m, day: d))!
}

final class TraceParserTests: XCTestCase {
    private let parser = TraceParser()

    func testParsesBoardFormat() {
        let trace = parser.parse(MealSamples.boardText)
        XCTAssertEqual(trace?.vegetable, "小白菜")
        XCTAssertEqual(trace?.safetyIntervalDays, 7)
        XCTAssertEqual(trace?.farm, "青浦蔬菜基地")
    }

    func testParsesColonFormat() {
        let trace = parser.parse(MealSamples.compliantText)
        XCTAssertEqual(trace?.safetyIntervalDays, 14)
    }

    /// 读不出来就返回 nil，**绝不用常识补 0 天**。
    func testGarbageYieldsNil() {
        XCTAssertNil(parser.parse("欢迎光临今日特价"))
    }

    func testMissingFieldsAreReported() {
        let missing = parser.missingFields(in: "品名 小白菜 产地 青浦")
        XCTAssertTrue(missing.contains("安全间隔期"))
        XCTAssertTrue(missing.contains("采收日期"))
    }

    func testImplausibleIntervalRejected() {
        XCTAssertNil(parser.parse("品名 小白菜 产地 青浦 安全间隔期 900天 末次施药 20261005 采收日期 20261011"))
    }
}

final class BatchTraceTests: XCTestCase {
    private var trace: BatchTrace {
        BatchTrace(batchId: "B1", vegetable: "小白菜", farm: "青浦",
                   lastSprayedOn: day(10, 5), safetyIntervalDays: 7,
                   harvestedOn: day(10, 11), supplier: "城东配送")
    }

    /// 施药 10/05、间隔 7 天 → 10/12 才能采，10/11 采就是超期。
    func testOverHarvestDetected() {
        XCTAssertFalse(trace.isSafe(on: day(10, 12), calendar: cal))
        XCTAssertEqual(trace.verdict(on: day(10, 12), calendar: cal), .overHarvested)
    }

    func testOnTheDayIsAllowed() {
        let compliant = BatchTrace(batchId: "B1", vegetable: "小白菜", farm: "青浦",
                                   lastSprayedOn: day(10, 5), safetyIntervalDays: 7,
                                   harvestedOn: day(10, 12), supplier: "城东配送")
        XCTAssertTrue(compliant.isSafe(on: day(10, 12), calendar: cal))
    }

    func testDaysSinceSpray() {
        XCTAssertEqual(trace.daysSinceSpray(on: day(10, 12), calendar: cal), 7)
    }
}

final class NutritionTests: XCTestCase {
    private var menu: LunchMenu {
        LunchMenu(date: Date(), items: [
            LunchMenu.Dish(name: "米饭", grams: 150, nutrient: .rice),
            LunchMenu.Dish(name: "小白菜", grams: 120, nutrient: .cabbage)
        ])
    }

    func testProteinGapIsDetected() {
        let gaps = NutritionTarget.evaluate(menu)
        XCTAssertTrue(gaps.contains { $0.title == "蛋白质" })
    }

    /// 长期问题要用"长期"的话术，一顿低不等于缺。
    func testAdviceDoesNotPanicOverOneMeal() {
        for gap in NutritionTarget.evaluate(menu) {
            XCTAssertFalse(gap.advice.contains("立刻"))
            XCTAssertFalse(gap.advice.contains("严重缺乏"))
        }
    }

    func testPercentIsSane() {
        for gap in NutritionTarget.evaluate(menu) {
            XCTAssertGreaterThan(gap.percent, 0)
            XCTAssertLessThanOrEqual(gap.percent, 100)
        }
    }
}

final class WeeklyTrendTests: XCTestCase {
    private var trend: WeeklyTrend {
        WeeklyTrend(days: MealSamples.weekRecords())
    }

    func testWeekHasSevenDays() {
        XCTAssertEqual(trend.coverageDays, 7)
    }

    func testOverHarvestDaysAreCounted() {
        XCTAssertEqual(trend.overHarvestDays, 1)
    }

    /// 少于 4 天就下"长期问题"的结论，是在制造焦虑。
    func testNoConclusionWithTooFewDays() {
        let short = WeeklyTrend(days: Array(MealSamples.weekRecords().prefix(2)))
        XCTAssertTrue(short.allFindings.isEmpty)
        XCTAssertEqual(short.coverageDays, 2)
    }

    func testWeekFindsRealGaps() {
        let findings = trend.allFindings.map(\.title)
        XCTAssertTrue(findings.contains("钙") || findings.contains("维生素 A"))
    }

    func testAdviceNeverPanics() {
        for finding in trend.allFindings {
            XCTAssertFalse(finding.advice.contains("立刻"))
            XCTAssertTrue(finding.advice.contains("天"))
        }
    }
}

final class InquiryDraftTests: XCTestCase {
    private var overdue: BatchTrace {
        TraceParser().parse(MealSamples.boardText)!
    }

    func testOverHarvestDraftAsksAboutDate() {
        let draft = InquiryDraft(school: "阳光镇中心小学", batch: overdue, today: day(10, 12))
        XCTAssertTrue(draft.questions.first?.contains("采收日期") ?? false)
    }

    func testCompliantBatchSkipsAccusation() {
        let good = TraceParser().parse(MealSamples.compliantText)!
        let draft = InquiryDraft(school: "阳光镇中心小学", batch: good, today: day(10, 12))
        XCTAssertFalse(draft.questions.contains { $0.contains("按规定应") })
    }

    func testDraftAlwaysAsksForReport() {
        let draft = InquiryDraft(school: "阳光镇中心小学", batch: overdue, today: day(10, 12))
        XCTAssertTrue(draft.questions.contains { $0.contains("检测报告") })
        XCTAssertTrue(draft.shareText.contains("批次"))
    }
}
