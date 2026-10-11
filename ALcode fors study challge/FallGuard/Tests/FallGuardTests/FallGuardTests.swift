import XCTest
@testable import FallGuard

final class FallDetectorTests: XCTestCase {
    private let detector = FallDetector()

    func testHardFallWithStillnessNeedsHelp() {
        let v = detector.verdict(samples: SampleMotion.fallAndStill())
        XCTAssertTrue(v.isFall)
        XCTAssertEqual(v.phase, .needHelp)
        XCTAssertGreaterThan(v.impactG, 2.5)
        XCTAssertGreaterThan(v.stillnessSeconds, 25)
    }

    func testFallButRecoveredIsNotEscalated() {
        XCTAssertEqual(detector.verdict(samples: SampleMotion.fallAndRecover()).phase, .recovered)
    }

    func testWalkingIsNotAFall() {
        let v = detector.verdict(samples: SampleMotion.walking())
        XCTAssertFalse(v.isFall)
        XCTAssertEqual(v.phase, .idle)
    }

    /// 放下手机也会产生冲击——只看冲击的算法会在这里翻车
    func testPuttingPhoneDownDoesNotTrigger() {
        var samples = SampleMotion.walking(seconds: 1)
        samples += [AccelSample(x: 0.1, y: 0.1, z: 1.0), AccelSample(x: 0.02, y: 0.01, z: 1.0)]
        XCTAssertFalse(detector.verdict(samples: samples).isFall)
    }

    func testVerdictAlwaysExplainsItself() {
        let v = detector.verdict(samples: SampleMotion.fallAndStill())
        XCTAssertFalse(v.reasons.isEmpty)
        XCTAssertTrue(v.reasons.contains { $0.contains("冲击") })
    }

    func testEmptySamplesAreSafe() {
        XCTAssertFalse(detector.verdict(samples: []).isFall)
    }
}

final class VoiceCheckFlowTests: XCTestCase {
    private let flow = VoiceCheckFlow(questions: VoicePrompt.questions)

    func testAnyResponseStopsEscalation() {
        XCTAssertFalse(flow.needsEscalation(responses: [false, true, false]))
        XCTAssertFalse(flow.needsEscalation(responses: [true]))
    }

    func testAllSilentNeedsEscalation() {
        XCTAssertTrue(flow.needsEscalation(responses: [false, false, false]))
    }

    /// 问的是"能不能回我一句"，不是"你是不是摔了"——要的是回应，不是答案。
    func testQuestionsAskForResponseNotDiagnosis() {
        for q in flow.questions {
            XCTAssertFalse(q.contains("摔"))
        }
    }
}

final class EscalationPlannerTests: XCTestCase {
    private let verdict = FallVerdict(isFall: true, phase: .needHelp, impactG: 4.2, stillnessSeconds: 40, reasons: [])

    private var contacts: [EmergencyContact] {
        [
            EmergencyContact(name: "女儿", relation: "子女", phone: "1", tier: .family),
            EmergencyContact(name: "儿子", relation: "同住", phone: "2", tier: .neighbor),
            EmergencyContact(name: "邻居", relation: "邻居", phone: "3", tier: .neighbor, preAuthorized: false)
        ]
    }

    private func buildPlan() -> EscalationPlan {
        EscalationPlanner().plan(contacts: contacts, verdict: verdict, personName: "李伯", location: "小区")
    }

    func testUnauthorizedContactsAreSkipped() {
        let plan = buildPlan()
        XCTAssertEqual(plan.steps.count, 2)
        XCTAssertFalse(plan.steps.contains { $0.target.contains("邻居") })
    }

    func testNearestFirstOrdering() {
        XCTAssertTrue(buildPlan().steps.first?.target.contains("儿子") ?? false)
    }

    func testMessageCarriesActionableFacts() {
        let message = EscalationPlanner().message(for: contacts[0], verdict: verdict, personName: "李伯", location: "阳光小区 402")
        XCTAssertTrue(message.contains("李伯"))
        XCTAssertTrue(message.contains("阳光小区 402"))
        XCTAssertTrue(message.contains("120"))
    }

    func testMessageFirstChannelForNight() {
        XCTAssertTrue(buildPlan().steps.first?.channel.contains("短信") ?? false)
    }
}

@MainActor
final class GuardViewModelTests: XCTestCase {
    func testSilentFallKeepsPlan() {
        let vm = GuardViewModel()
        vm.ingest(samples: SampleMotion.fallAndStill())
        XCTAssertNotNil(vm.plan)
    }

    func testWalkingClearsPlan() {
        let vm = GuardViewModel()
        vm.ingest(samples: SampleMotion.walking())
        XCTAssertNil(vm.plan)
    }
}
