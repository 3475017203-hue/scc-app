import Foundation

/// 药。真正决定"要不要紧"的不是药名，而是**漏服之后会怎样**。
enum DrugClass: String, CaseIterable, Codable {
    case routine
    case glucoseLowering = "降糖药"
    case anticoagulant = "抗凝药"
    case antiarrhythmic = "抗心律药"
    case cardiacGlycoside = "地高辛类"
    case sedative = "镇静催眠药"
    case antibiotic
    case other

    /// 漏服后能不能自己补
    var canSelfMakeUp: Bool {
        switch self {
        case .glucoseLowering, .anticoagulant, .antiarrhythmic, .cardiacGlycoside: false
        case .routine, .sedative, .antibiotic, .other: true
        }
    }

    var urgencyNote: String {
        switch self {
        case .glucoseLowering: "漏服后血糖可能明显波动，不要自行加倍补服，按医生交代处理"
        case .anticoagulant: "漏服影响凝血，不要自行补服，需问开药医生"
        case .antiarrhythmic: "漏服可能诱发心律失常，不要自行补服"
        case .cardiacGlycoside: "过量会中毒，绝对不要自行补服"
        case .routine: "多数情况按下一次常规剂量服，不加倍"
        case .sedative: "不要补双倍，避免次日嗜睡跌倒"
        case .antibiotic: "漏服影响血药浓度，按说明书或咨询医生"
        case .other: "不确定时请咨询医生或药师"
        }
    }
}

struct Medication: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var drugClass: DrugClass
    /// 每天几次
    var timesPerDay: Int
    /// 服用时间点（小时），如 [8, 20] 表示早八晚八
    var hours: [Int]
    var dose: String
    var withFood: Bool
    var note: String

    init(id: UUID = UUID(), name: String, drugClass: DrugClass, timesPerDay: Int, hours: [Int], dose: String, withFood: Bool = false, note: String = "") {
        self.id = id
        self.name = name
        self.drugClass = drugClass
        self.timesPerDay = timesPerDay
        self.hours = hours
        self.dose = dose
        self.withFood = withFood
        self.note = note
    }
}

enum DoseState: String, Codable, Hashable {
    case pending
    case taken
    case missed
    case skippedByDoctor = "医嘱停药"

    var label: String {
        switch self {
        case .pending: "待服用"
        case .taken: "已服用"
        case .missed: "漏服"
        case .skippedByDoctor: "医嘱停药"
        }
    }
}

struct DoseSlot: Identifiable, Hashable {
    let id: String
    let medication: Medication
    let hour: Int
    var state: DoseState
    /// 谁确认的：本人 / 家属。老人自己点掉提醒，依赖就白建了。
    var confirmedBy: String?

    var scheduledAt: Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }
}
