import XCTest
@testable import SafeHarvest

private let cal = Calendar(identifier: .gregorian)

private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d))!
}

private let leafy = Crop(id: "leafy", name: "叶菜类", emoji: "🥬")

final class IntervalEngineTests: XCTestCase {
    func testEarliestHarvestIsIntervalAfterApplication() throws {
        let app = Application(crop: leafy, label: LabelReading(safetyIntervalDays: .days(7)), appliedOn: date(2026, 5, 12))
        let window = try IntervalEngine.window(for: app, calendar: cal)
        let gap = cal.dateComponents([.day], from: date(2026, 5, 12), to: window.earliestHarvestDate).day
        XCTAssertEqual(gap, 7)
    }

    /// 边界：间隔期最后一天当天**不能**采收，第二天才能吃。
    func testBoundaryDayIsNotHarvestable() throws {
        let app = Application(crop: leafy, label: LabelReading(safetyIntervalDays: .days(3)), appliedOn: date(2026, 5, 12))
        let window = try IntervalEngine.window(for: app, calendar: cal)
        XCTAssertFalse(window.isReady(on: date(2026, 5, 15), calendar: cal))
        XCTAssertTrue(window.isReady(on: date(2026, 5, 16), calendar: cal))
    }

    /// 同一茬菜打了两遍药，只能按最后一次算——这是农残超标最常见的成因。
    func testLatestApplicationWins() throws {
        let first = Application(crop: leafy, label: LabelReading(safetyIntervalDays: .days(7)), appliedOn: date(2026, 5, 1))
        let second = Application(crop: leafy, label: LabelReading(safetyIntervalDays: .days(7)), appliedOn: date(2026, 5, 12))
        let window = try IntervalEngine.window(for: [first, second], crop: leafy, calendar: cal)
        XCTAssertEqual(window.appliedOn, date(2026, 5, 12))
        let gap = cal.dateComponents([.day], from: date(2026, 5, 12), to: window.earliestHarvestDate).day
        XCTAssertEqual(gap, 7)
    }

    /// 读不到间隔期时**必须失败**，绝不能用默认值糊弄。
    func testUnknownIntervalThrows() {
        let app = Application(crop: leafy, label: LabelReading(), appliedOn: date(2026, 5, 12))
        XCTAssertThrowsError(try IntervalEngine.window(for: app, calendar: cal))
    }

    func testViolationDetection() {
        let app = Application(crop: leafy, label: LabelReading(safetyIntervalDays: .days(7)), appliedOn: date(2026, 5, 12))
        XCTAssertTrue(app.isViolation(harvestedOn: date(2026, 5, 16), calendar: cal))
        XCTAssertFalse(app.isViolation(harvestedOn: date(2026, 5, 20), calendar: cal))
    }
}

final class LabelParserTests: XCTestCase {
    private let parser = LabelParser()

    func testParsesStandardLabel() {
        let raw = "农药名称: 烯酰吗啉\n有效成分: 烯酰吗啉 50%\n安全间隔期: 7天\n每季最大使用次数: 3次"
        let reading = parser.parse(raw)
        XCTAssertEqual(reading.safetyIntervalDays.dayCount, 7)
        XCTAssertTrue(reading.isUsable)
        XCTAssertEqual(reading.maxApplications, .text("3 次"))
    }

    func testParsesAlternateWording() {
        let reading = parser.parse("采收安全间隔期 3 天\n每季最多使用次数 2 次")
        XCTAssertEqual(reading.safetyIntervalDays.dayCount, 3)
    }

    func testUnreadableLabelYieldsUnknown() {
        let reading = parser.parse("XXXXXXXXXXXXXXX")
        XCTAssertEqual(reading.safetyIntervalDays, .unknown)
        XCTAssertFalse(reading.isUsable)
        XCTAssertTrue(reading.missing.contains("安全间隔期"))
    }

    /// OCR 常把冒号和空格吃掉，解析器必须顶得住。
    func testSurvivesMissingColonAndSpaces() {
        let reading = parser.parse("安全间隔期7天")
        XCTAssertEqual(reading.safetyIntervalDays.dayCount, 7)
    }

    /// 离谱的值直接判定为读错，而不是照单全收。
    func testRejectsImplausibleValues() {
        let reading = parser.parse("安全间隔期: 900天")
        XCTAssertEqual(reading.safetyIntervalDays, .unknown)
    }
}

final class PesticideDictionaryTests: XCTestCase {
    private let dict = PesticideDictionary.standard
    private let leafy = Crop(id: "leafy", name: "叶菜类", emoji: "🥬")

    func testMatchingSourcesAreConfirmed() {
        let reading = LabelReading(pesticideName: .text("烯酰吗啉"),
                                   activeIngredient: .text("烯酰吗啉 50%"),
                                   safetyIntervalDays: .days(7))
        guard case .matched(_, let days) = dict.lookup(reading: reading, crop: leafy) else {
            return XCTFail("应当匹配成功")
        }
        XCTAssertEqual(days, 7)
    }

    /// OCR 把 7 读成 1 —— 两个信源打架时必须报"对不上"，不能静默取其一。
    func testMismatchIsSurfacedNotSilentlyResolved() {
        let reading = LabelReading(pesticideName: .text("烯酰吗啉"),
                                   activeIngredient: .text("烯酰吗啉"),
                                   safetyIntervalDays: .days(1))
        guard case .mismatch(let label, let dictionary) = dict.lookup(reading: reading, crop: leafy) else {
            return XCTFail("应当报不一致")
        }
        XCTAssertEqual(label, 1)
        XCTAssertEqual(dictionary, 7)
    }

    func testUnknownPesticideFallsBackToLabel() {
        let reading = LabelReading(pesticideName: .text("某新药"),
                                   safetyIntervalDays: .days(5))
        guard case .notFound = dict.lookup(reading: reading, crop: leafy) else {
            return XCTFail("词典没有收录，应回落")
        }
    }

    func testCropWithoutDictionaryEntryFallsBack() {
        let reading = LabelReading(pesticideName: .text("草铵膦"),
                                   safetyIntervalDays: .days(30))
        guard case .noIntervalForCrop = dict.lookup(reading: reading, crop: Crop(id: "bean", name: "豆类", emoji: "🫛")) else {
            return XCTFail("豆类无条目，应回落")
        }
    }

    /// 未经校对的条目必须自曝来源不足——这是上一轮竞品对比给出的最大短板。
    func testEveryEntryDeclaresItsSource() {
        for entry in PesticideDictionary.standard.entries {
            XCTAssertFalse(entry.source.basis.isEmpty)
            XCTAssertFalse(entry.source.retrievedOn.isEmpty)
            XCTAssertFalse(entry.source.verified, "演示词典尚未校对，不应标成已校对")
            XCTAssertTrue(entry.source.line.contains("以药瓶标签为准"))
        }
    }
}
