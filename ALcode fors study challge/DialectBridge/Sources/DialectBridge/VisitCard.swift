import Foundation

/// 最终产物：一张可以递给医生的卡片。
/// 老人"说不清"，医生"读不懂"——卡片解决"读"，朗读解决"说"。
struct VisitCard: Identifiable, Codable, Hashable {
    let id: UUID
    let createdAt: Date
    let patient: PatientProfile
    let reportedSymptoms: [NormalizedSegment]
    let bodySpots: [BodySpot]
    /// 病程，例如"约 2 天前开始"
    let onsets: [String]
    /// 词库没覆盖、需要医生补充问诊的部分
    let unresolved: [String]
    let pathway: CarePathway

    struct PatientProfile: Codable, Hashable {
        var nickname: String = "我"
        var age: Int = 70
        var gender: String = "未填写"
        var chronicConditions: [String] = []
        var medications: [String] = []
        var allergies: [String] = []
        var dialect: DialectRegion = .putonghua
    }

    var headline: String {
        let words = reportedSymptoms.filter { !$0.isNegated }.map(\.term.standard)
        let places = bodySpots.map(\.display)
        let all = words + places
        return all.isEmpty ? "待补充" : all.joined(separator: "、")
    }

    /// 可复制 / 可分享给家属的纯文本
    var plainText: String {
        var lines: [String] = []
        lines.append("【就诊卡】\(patient.nickname) · \(patient.age) 岁 · \(patient.gender) · 方言：\(patient.dialect.rawValue)")
        lines.append("主诉：\(headline)")
        if !onsets.isEmpty {
            lines.append("病程：\(onsets.joined(separator: "、"))")
        }
        lines.append("建议科室：\(pathway.department)（\(pathway.urgency.label)）")
        if !patient.chronicConditions.isEmpty { lines.append("既往病史：\(patient.chronicConditions.joined(separator: "、"))") }
        if !patient.medications.isEmpty { lines.append("正在用药：\(patient.medications.joined(separator: "、"))") }
        if !patient.allergies.isEmpty { lines.append("过敏史：\(patient.allergies.joined(separator: "、"))") }
        lines.append("")
        if !bodySpots.isEmpty {
            lines.append("老人指认位置：")
            lines.append(contentsOf: bodySpots.map { "· \($0.region.doctorText)（\($0.display)）" })
            lines.append("")
        }
        lines.append("需要医生重点关注：")
        lines.append(contentsOf: pathway.advisories)
        lines.append("")
        lines.append("老人本话（方言原话 → 规范医学词）：")
        lines.append(contentsOf: reportedSymptoms.map {
            $0.isNegated ? "「\($0.negationCue ?? "")\($0.source)」→ 否认\($0.standard)"
                         : "「\($0.source)」→ \($0.standard)"
        })
        lines.append("")
        lines.append("大白话提醒：")
        lines.append(contentsOf: pathway.plainLanguage.map { "· \($0)" })
        if !unresolved.isEmpty {
            lines.append("")
            lines.append("未能归类、需要医生补充问诊：")
            lines.append(contentsOf: unresolved.map { "「\($0)」" })
        }
        return lines.joined(separator: "\n")
    }
}
