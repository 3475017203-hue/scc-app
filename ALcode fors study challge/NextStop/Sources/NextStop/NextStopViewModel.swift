import Foundation
import SwiftUI

@MainActor
final class NextStopViewModel: ObservableObject {
    @Published var route: Route = SampleCity.line7
    @Published var currentIndex = 0
    @Published var destinationIndex = 5
    @Published var canHearAnnouncements = false
    @Published private(set) var lastStopHeard: Int?
    @Published private(set) var plan: RidePlan

    let coach = RideCoach()

    init() {
        let coach = RideCoach()
        plan = coach.plan(route: SampleCity.line7, currentStopIndex: 0, destinationIndex: 5, canHearAnnouncements: false, lastStopHeard: nil)
    }

    var currentStop: Stop { route.stops[min(currentIndex, route.stops.count - 1)] }
    var destination: Stop { route.stops[min(destinationIndex, route.stops.count - 1)] }
    var stopsLeft: Int { max(0, destinationIndex - currentIndex) }

    /// 下一站；已经过了就不再显示
    var nextStop: Stop? {
        let next = currentIndex + 1
        guard next < route.stops.count, next <= destinationIndex else { return nil }
        return route.stops[next]
    }

    var isAtDestination: Bool { currentIndex >= destinationIndex }

    func advance(hearingAnnouncement: Bool = false) {
        if hearingAnnouncement { lastStopHeard = currentIndex }
        currentIndex = min(currentIndex + 1, route.stops.count - 1)
        refresh()
    }

    func rewind() {
        currentIndex = max(0, currentIndex - 1)
        refresh()
    }

    func refresh() {
        plan = coach.plan(route: route, currentStopIndex: currentIndex, destinationIndex: destinationIndex, canHearAnnouncements: canHearAnnouncements, lastStopHeard: lastStopHeard)
    }

    var hapticName: String { plan.hapticName }
}
