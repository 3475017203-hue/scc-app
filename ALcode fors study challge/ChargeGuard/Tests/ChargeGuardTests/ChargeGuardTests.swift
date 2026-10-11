import XCTest
@testable import ChargeGuard

final class ChargeClassifierTests: XCTestCase {
    private let classifier = ChargeClassifier()

    func testNormalChargingIsNormal() {
        let (risk, _) = classifier.risk(SampleAudio.signature(for: .normal))
        XCTAssertEqual(risk, .normal)
    }

    func testAgingChargerDetected() {
        let (risk, reasons) = classifier.risk(SampleAudio.signature(for: .aging))
        XCTAssertEqual(risk, .aging)
        XCTAssertFalse(reasons.isEmpty)
    }

    func testCrackleIsSuspect() {
        let (risk, _) = classifier.risk(SampleAudio.signature(for: .suspect))
        XCTAssertEqual(risk, .suspect)
    }

    /// 焦糊味 + 噼啪声 = 立即撤离。这条不能错。
    func testSmellPlusCrackleIsDangerous() {
        let (risk, reasons) = classifier.risk(SampleAudio.signature(for: .dangerous))
        XCTAssertEqual(risk, .dangerous)
        XCTAssertTrue(reasons.contains { $0.contains("焦糊") })
    }

    func testSmellAloneIsDangerous() {
        var signature = SampleAudio.signature(for: .normal)
        signature.reportedSmell = true
        XCTAssertEqual(classifier.risk(signature).0, .dangerous)
    }

    func testQuietEnvironmentIsNormal() {
        let quiet = ChargeSignature(loudnessDB: -70, crackleRate: 0, whineLevel: 0,
                                    isRegularPulse: false, reportedSmell: false)
        XCTAssertEqual(classifier.risk(quiet).0, .normal)
    }

    /// 宁可多喊一次：分类器不提供"忽略"这个选项。
    func testEveryResultCarriesReason() {
        for kind in [SampleAudio.Kind.normal, .aging, .suspect, .dangerous] {
            XCTAssertFalse(classifier.risk(SampleAudio.signature(for: kind)).1.isEmpty)
        }
    }
}

final class EvacuationPlannerTests: XCTestCase {
    private let building = Building(name: "阳光小区 3 号楼", floors: 6,
                                    corridorLengths: [8, 9, 9, 9, 10],
                                    corridorBlocked: true, hasElevator: true)

    func testElevatorIsForbiddenInFire() {
        let route = EvacuationPlanner().route(from: 3, in: building)
        XCTAssertTrue(route.steps.contains { $0.contains("不要坐电梯") })
    }

    func testBlockedCorridorRaisesWarning() {
        XCTAssertTrue(EvacuationPlanner().route(from: 3, in: building).warnings.isEmpty == false)
    }

    func testHigherFloorTakesLonger() {
        let low = EvacuationPlanner().route(from: 2, in: building)
        let high = EvacuationPlanner().route(from: 6, in: building)
        XCTAssertGreaterThan(high.estimatedSeconds, low.estimatedSeconds)
    }

    func testRouteAlwaysEndsWithEmergencyCall() {
        XCTAssertTrue(EvacuationPlanner().route(from: 5, in: building).steps.contains { $0.contains("119") })
    }

    func testEveryoneIsWarnedFirst() {
        XCTAssertTrue(EvacuationPlanner().route(from: 4, in: building).steps.first?.contains("喊人") ?? false)
    }
}
