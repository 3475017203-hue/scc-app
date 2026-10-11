import Foundation

/// 漏服之后到底该怎么办——这是整个 App 最要紧的一段逻辑，
/// 也是市面提醒类 App 最容易出错的地方：**统一提示"补服"，可能出事。**
struct AdherenceEngine {
    /// 漏服宽限：过了计划时间多久才算漏服
    var gracePeriodMinutes: Int = 60

    func slots(for medications: [Medication], now: Date, confirmed: Set<String>) -> [DoseSlot] {
        medications.flatMap { med in
            med.hours.map { hour in
                let id = "\(med.id.uuidString)-\(hour)"
                let state: DoseState
                if confirmed.contains(id) {
                    state = .taken
                } else {
                    state = isMissed(med: med, hour: hour, now: now) ? .missed : .pending
                }
                return DoseSlot(id: id, medication: med, hour: hour, state: state,
                                confirmedBy: confirmed.contains(id) ? "家属" : nil)
            }
        }
        .sorted { $0.hour < $1.hour }
    }

    func isMissed(med: Medication, hour: Int, now: Date, calendar: Calendar = .current) -> Bool {
        let due = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
        let deadline = calendar.date(byAdding: .minute, value: gracePeriodMinutes, to: due) ?? due
        return now > deadline
    }

    /// 漏服处理建议。危险类别**只提示联系医生，不给补服动作**。
    func advice(for slot: DoseSlot) -> Advice {
        guard slot.state == .missed else {
            return Advice(action: slot.state == .taken ? "已完成" : "到时候再提醒",
                          tone: .neutral,
                          canSelfMakeUp: false,
                          detail: slot.medication.drugClass.urgencyNote)
        }
        let cls = slot.medication.drugClass
        if cls.canSelfMakeUp {
            return Advice(action: "按说明书处理，通常不加倍",
                          tone: cls == .sedative ? .warning : .neutral,
                          canSelfMakeUp: true,
                          detail: cls.urgencyNote)
        }
        return Advice(action: "请联系开药医生或药师",
                      tone: .critical,
                      canSelfMakeUp: false,
                      detail: cls.urgencyNote)
    }

    struct Advice: Hashable {
        enum Tone { case neutral, warning, critical }
        let action: String
        let tone: Tone
        let canSelfMakeUp: Bool
        let detail: String
    }

    /// 当日依从率，用来看"最近是不是总在漏"
    func adherenceRate(_ slots: [DoseSlot]) -> Double {
        let decided = slots.filter { $0.state != .pending }
        guard !decided.isEmpty else { return 1 }
        let taken = decided.filter { $0.state == .taken }.count
        return Double(taken) / Double(decided.count)
    }

    /// 一句话日报，给不在场的子女看
    func dailyReport(_ slots: [DoseSlot], person: String, on date: Date) -> String {
        let taken = slots.filter { $0.state == .taken }
        let missed = slots.filter { $0.state == .missed }
        var lines = ["【记得吃 · 用药日报】\(person) \(date.formatted(.dateTime.year().month().day()))"]
        lines.append("已服 \(taken.count) 次，漏服 \(missed.count) 次。")
        for slot in missed {
            lines.append("· \(slot.medication.name) \(slot.hour):00 漏服 —— \(slot.medication.drugClass.urgencyNote)")
        }
        lines.append(missed.isEmpty ? "今天全部按时，继续保持。" : "有漏服，请留意。")
        return lines.joined(separator: "\n")
    }
}
