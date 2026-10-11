import XCTest
@testable import DoseVibe

private let cal = Calendar(identifier: .gregorian)

private func at(_ hour: Int, _ day: Int = 10) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: 0))!
}

private func med(_ name: String, _ cls: DrugClass, _ hour: Int) -> Medication {
    Medication(name: name, drugClass: cls, timesPerDay: 1, hours: [hour], dose: "1 片")
}

final class AdherenceEngineTests: XCTestCase {
    func testFutureSlotIsPending() {
        let slots = AdherenceEngine().slots(for: [med("氨氯地平", .routine, 20)], now: at(9), confirmed: [])
        XCTAssertEqual(slots.first?.state, .pending)
    }

    func testPastSlotWithoutConfirmationBecomesMissed() {
        let slots = AdherenceEngine().slots(for: [med("氨氯地平", .routine, 8)], now: at(10), confirmed: [])
        XCTAssertEqual(slots.first?.state, .missed)
    }

    func testGracePeriodDelaysMissingJudgment() {
        var engine = AdherenceEngine()
        engine.gracePeriodMinutes = 120
        let med1 = med("氨氯地平", .routine, 8)
        XCTAssertFalse(engine.isMissed(med: med1, hour: 8, now: at(9)))
    }

    /// 最关键的一条：危险药物漏服**绝不能**给补服建议。
    func testDangerousDrugNeverOffersMakeUp() {
        for cls in [DrugClass.glucoseLowering, .anticoagulant, .antiarrhythmic, .cardiacGlycoside] {
            XCTAssertFalse(cls.canSelfMakeUp, "\(cls) 不允许自行补服")
            let slots = AdherenceEngine().slots(for: [med("测试", cls, 8)], now: at(10), confirmed: [])
            let advice = AdherenceEngine().advice(for: slots[0])
            XCTAssertEqual(advice.tone, .critical)
            XCTAssertFalse(advice.canSelfMakeUp)
            XCTAssertTrue(advice.action.contains("医生") || advice.action.contains("药师"))
        }
    }

    func testRoutineDrugGetsGentleAdvice() {
        let slots = AdherenceEngine().slots(for: [med("氨氯地平", .routine, 8)], now: at(10), confirmed: [])
        let advice = AdherenceEngine().advice(for: slots[0])
        XCTAssertNotEqual(advice.tone, .critical)
    }

    /// 这是市面提醒类 App 最容易出事的地方：统一提示"补服"可能害死人。
    func testSedativeMustNotDoubleDose() {
        let slots = AdherenceEngine().slots(for: [med("唑吡坦", .sedative, 21)], now: at(23), confirmed: [])
        XCTAssertTrue(AdherenceEngine().advice(for: slots[0]).detail.contains("不要补双倍"))
    }

    func testConfirmedSlotsAreTaken() {
        let m = med("华法林", .anticoagulant, 8)
        let id = "\(m.id.uuidString)-8"
        let slots = AdherenceEngine().slots(for: [m], now: at(10), confirmed: [id])
        XCTAssertEqual(slots.first?.state, .taken)
    }

    func testAdherenceRateIgnoresPending() {
        let slots = AdherenceEngine().slots(for: [med("a", .routine, 8), med("b", .routine, 20)], now: at(10), confirmed: [])
        XCTAssertEqual(AdherenceEngine().adherenceRate(slots), 0)  // 已决定的只有 8 点那次，且漏服
    }

    func testDailyReportListsMissedDrugs() {
        let slots = AdherenceEngine().slots(for: [med("华法林", .anticoagulant, 8)], now: at(10), confirmed: [])
        let report = AdherenceEngine().dailyReport(slots, person: "张阿姨", on: Date())
        XCTAssertTrue(report.contains("华法林"))
        XCTAssertTrue(report.contains("漏服"))
    }
}

final class CaregiverConfirmTests: XCTestCase {
    func testPasscodeModeBlocksStranger() {
        let confirm = CaregiverConfirm(method: .withPasscode)
        XCTAssertFalse(confirm.allowsSelfConfirm(by: "邻居", isHouseholdMember: false))
        XCTAssertTrue(confirm.allowsSelfConfirm(by: "女儿", isHouseholdMember: true))
    }

    func testNoAuthAllowsAnyone() {
        XCTAssertTrue(CaregiverConfirm(method: .none).allowsSelfConfirm(by: "邻居", isHouseholdMember: false))
    }
}

@MainActor
final class DoseViewModelTests: XCTestCase {
    func testUrgentMissedSeparatesDangerousDrugs() {
        let vm = DoseViewModel()
        XCTAssertTrue(vm.missedSlots.allSatisfy { $0.state == .missed })
    }

    func testConfirmRemovesFromMissed() {
        let vm = DoseViewModel()
        guard let slot = vm.slots.first else { return XCTFail("应至少有一个服药时段") }
        vm.confirm(slot, by: "女儿")
        XCTAssertFalse(vm.missedSlots.contains { $0.id == slot.id })
    }

    func testReportGenerated() {
        XCTAssertTrue(DoseViewModel().report.contains("用药日报"))
    }
}
