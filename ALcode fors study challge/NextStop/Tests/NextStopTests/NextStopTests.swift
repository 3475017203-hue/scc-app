import XCTest
@testable import NextStop

final class RideCoachTests: XCTestCase {
    private let coach = RideCoach()
    private let route = SampleCity.line7

    func testHardOfHearingMeansLikelyMiss() {
        let plan = coach.plan(route: route, currentStopIndex: 0, destinationIndex: 5, canHearAnnouncements: false, lastStopHeard: nil)
        XCTAssertEqual(plan.risk, .willLikelyMiss)
        XCTAssertTrue(plan.actions.contains { $0.contains("每一站都会震动提醒") })
    }

    func testNoisyStopRaisesRiskForEveryone() {
        let plan = coach.plan(route: route, currentStopIndex: 3, destinationIndex: 5, canHearAnnouncements: true, lastStopHeard: 3)
        XCTAssertEqual(plan.risk, .mightMiss)
        XCTAssertTrue(plan.actions.contains { $0.contains("噪声大") })
    }

    func testEasyFinalStopWithHearingIsSmooth() {
        let plan = coach.plan(route: route, currentStopIndex: 4, destinationIndex: 5, canHearAnnouncements: true, lastStopHeard: 4)
        XCTAssertEqual(plan.risk, .smooth)
    }

    func testReminderStartsTwoStopsBefore() {
        let plan = coach.plan(route: route, currentStopIndex: 1, destinationIndex: 5, canHearAnnouncements: true, lastStopHeard: 1)
        XCTAssertEqual(plan.remindFromStopIndex, 3)
    }

    /// 报站没听见，是坐过站的直接原因——要单独提醒。
    func testMissedAnnouncementAddsReminder() {
        let plan = coach.plan(route: route, currentStopIndex: 2, destinationIndex: 5, canHearAnnouncements: true, lastStopHeard: 0)
        XCTAssertTrue(plan.actions.contains { $0.contains("报站可能没听见") })
    }

    func testAlreadyArrivedIsSmooth() {
        let plan = coach.plan(route: route, currentStopIndex: 5, destinationIndex: 5, canHearAnnouncements: false, lastStopHeard: 5)
        XCTAssertEqual(plan.risk, .smooth)
    }

    func testHapticIntensityMatchesRisk() {
        let smooth = coach.plan(route: route, currentStopIndex: 4, destinationIndex: 5, canHearAnnouncements: true, lastStopHeard: 4).hapticName
        let risky = coach.plan(route: route, currentStopIndex: 0, destinationIndex: 5, canHearAnnouncements: false, lastStopHeard: nil).hapticName
        XCTAssertNotEqual(smooth, risky)
    }

    func testTransferStopWarnsAboutGettingLost() {
        let plan = coach.plan(route: route, currentStopIndex: 2, destinationIndex: 3, canHearAnnouncements: true, lastStopHeard: 2)
        XCTAssertTrue(plan.actions.contains { $0.contains("换乘") })
    }
}

final class LastDepartureTests: XCTestCase {
    func testAfterLastBusSaysDoNotWait() {
        XCTAssertTrue(SampleCity.lastDepartureRisk(route: SampleCity.line7, nowMinutes: 22 * 60).contains("别再等"))
    }

    func testNearLastBusWarns() {
        XCTAssertTrue(SampleCity.lastDepartureRisk(route: SampleCity.line7, nowMinutes: 20 * 60 + 45).contains("不到半小时"))
    }

    func testPlentyOfTimeIsCalm() {
        XCTAssertTrue(SampleCity.lastDepartureRisk(route: SampleCity.line7, nowMinutes: 9 * 60).contains("还有时间"))
    }
}

@MainActor
final class NextStopViewModelTests: XCTestCase {
    func testAdvancesAndStopsAtDestination() {
        let vm = NextStopViewModel()
        for _ in 0..<10 { vm.advance() }
        XCTAssertTrue(vm.isAtDestination)
        XCTAssertNil(vm.nextStop)
    }

    func testMissingAnnouncementIsRecorded() {
        let vm = NextStopViewModel()
        vm.advance(hearingAnnouncement: true)
        XCTAssertEqual(vm.lastStopHeard, 0)
    }

    func testRewindGoesBack() {
        let vm = NextStopViewModel()
        vm.advance()
        vm.rewind()
        XCTAssertEqual(vm.currentIndex, 0)
    }

    func testNeverGoesNegative() {
        let vm = NextStopViewModel()
        vm.rewind()
        XCTAssertEqual(vm.currentIndex, 0)
    }
}
