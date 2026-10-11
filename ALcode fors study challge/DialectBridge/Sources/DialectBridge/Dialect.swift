import Foundation

/// 方言片区。归一化规则、常见误识别词表按片区加载。
enum DialectRegion: String, CaseIterable, Identifiable, Codable {
    case putonghua = "普通话"
    case wu = "吴语（沪/苏）"
    case cantonese = "粤语"
    case minnan = "闽南语"
    case sichuan = "西南官话"
    case minyue = "闽东/客家"

    var id: String { rawValue }

    var hint: String {
        switch self {
        case .putonghua: "标准普通话，无需归一化"
        case .wu: "苏州话、上海话、杭州话"
        case .cantonese: "广东话、香港话"
        case .minnan: "闽南话、厦门话、潮州话"
        case .sichuan: "四川话、重庆话"
        case .minyue: "福州话、宁德话、客家话"
        }
    }
}

enum SymptomCategory: String, CaseIterable, Identifiable, Codable {
    case pain = "疼痛"
    case cardiopulmonary = "心肺"
    case digestive = "消化"
    case neuro = "神经/意识"
    case metabolic = "代谢/内分泌"
    case trauma = "外伤"
    case vision = "视力"
    case general = "其他"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pain: "bolt.heart.fill"
        case .cardiopulmonary: "waveform.path.ecg"
        case .digestive: "fork.knife"
        case .neuro: "brain.head.profile"
        case .metabolic: "drop.degreesign"
        case .trauma: "cross.case.fill"
        case .vision: "eye.fill"
        case .general: "text.bubble.fill"
        }
    }

    var suggestedDepartment: String {
        switch self {
        case .pain: "疼痛科 / 全科"
        case .cardiopulmonary: "心内科 / 呼吸科（请直接到分诊台）"
        case .digestive: "消化内科"
        case .neuro: "神经内科 / 急诊"
        case .metabolic: "内分泌科"
        case .trauma: "外科 / 急诊清创"
        case .vision: "眼科"
        case .general: "全科 / 社区医院"
        }
    }

    var defaultUrgency: Urgency { .routine }
}

enum Urgency: Int, Codable, Comparable {
    case routine = 0, soon = 1, urgent = 2, emergency = 3

    static func < (l: Urgency, r: Urgency) -> Bool { l.rawValue < r.rawValue }

    var label: String {
        switch self {
        case .routine: "常规门诊"
        case .soon: "尽快就诊（1–3 天内）"
        case .urgent: "急需就诊（当天）"
        case .emergency: "⚠️ 立即急诊 / 呼叫 120"
        }
    }
}

/// 一条医学术语的"多方言说法"。
struct MedicalTerm: Identifiable, Codable, Hashable {
    let id: String
    /// 规范医学词（医生看的就是这个）
    let standard: String
    /// 老人平时真会说的说法（含口语、错别字、近音词）
    let colloquialisms: [String]
    /// 给医生看的补充说明
    let doctorNote: String
    let category: SymptomCategory
    /// 该说法属于哪些方言片区（空数组 = 通用）
    let regions: [DialectRegion]
    var urgency: Urgency { urgencyOverride ?? category.defaultUrgency }
    var urgencyOverride: Urgency?

    init(_ id: String, _ standard: String, colloquialisms: [String],
         note: String, category: SymptomCategory,
         regions: [DialectRegion] = [], urgency: Urgency? = nil) {
        self.id = id
        self.standard = standard
        self.colloquialisms = colloquialisms
        self.doctorNote = note
        self.category = category
        self.regions = regions
        self.urgencyOverride = urgency
    }
}
