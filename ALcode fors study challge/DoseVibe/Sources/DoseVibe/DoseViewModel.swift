import Foundation
import SwiftUI

@MainActor
final class DoseViewModel: ObservableObject {
    @Published var personName = "张阿姨"
    @Published var medications: [Medication] = DoseSamples.common
    @Published private(set) var confirmed: Set<String> = []
    @Published private(set) var now = Date()

    let engine = AdherenceEngine()
    let confirmer = CaregiverConfirm(method: .withPasscode)
    private let haptic: DoseHapticPlaying

    init(haptic: DoseHapticPlaying = SilentDoseHapticPlayer()) {
        self.haptic = haptic
    }

    var slots: [DoseSlot] {
        engine.slots(for: medications, now: now, confirmed: confirmed)
    }

    var missedSlots: [DoseSlot] {
        slots.filter { $0.state == .missed }
    }

    /// 漏服后**不能自行补服**的那些
    var urgentMissed: [DoseSlot] {
        missedSlots.filter { !$0.medication.drugClass.canSelfMakeUp }
    }

    var adherence: Double {
        engine.adherenceRate(slots)
    }

    func confirm(_ slot: DoseSlot, by person: String) {
        confirmed.insert(slot.id)
        haptic.play(DoseHaptic.due.pattern())
    }

    func simulateMissed(_ slot: DoseSlot) {
        confirmed.remove(slot.id)
        haptic.play(DoseHaptic.overdue.pattern())
    }

    /// 只播震动与文案，**不提供补服按钮**——危险药物这是硬规矩。
    func notify() {
        if !urgentMissed.isEmpty {
            haptic.play(DoseHaptic.urgent.pattern())
        } else if !missedSlots.isEmpty {
            haptic.play(DoseHaptic.overdue.pattern())
        } else {
            haptic.play(DoseHaptic.due.pattern())
        }
    }

    var report: String {
        engine.dailyReport(slots, person: personName, on: now)
    }
}
