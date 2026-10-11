import Foundation

/// 从命中的术语推导出一条"该怎么办"的行动建议。
struct CarePathway: Codable, Hashable {
    let urgency: Urgency
    let department: String
    let departmentRationale: String
    let advisories: [String]
    /// 老话 + 普通话的双语提示，提高依从性
    let plainLanguage: [String]

    static func derive(from segments: [NormalizedSegment], spots: [BodySpot] = [], age: Int) -> CarePathway {
        // 否定项不参与紧急度判定，也不该出现在"主诉"里
        let positive = segments.filter { !$0.isNegated }
        let negated = segments.filter(\.isNegated)
        let source = positive.isEmpty ? segments : positive

        let urgency = max(
            source.map(\.term.urgency).max() ?? .routine,
            spots.map { $0.region.urgencyFloor }.max() ?? .routine
        )
        let grouped = Dictionary(grouping: source, by: \.term.category)
        let main = grouped.max { $0.value.count < $1.value.count }?.key ?? .general

        var advisories = source.map { "· \($0.term.doctorNote)" }
        if !spots.isEmpty {
            for spot in spots {
                advisories.append("· 指认位置：\(spot.region.doctorText)（\(spot.display)）—— \(spot.region.hint)")
            }
        }
        for item in negated {
            advisories.append("· 患者**否认**「\(item.term.standard)」（原话「\(item.negationCue ?? "")\(item.source)」），请勿据此推断阳性体征。")
        }

        if age >= 65 {
            if source.contains(where: { $0.term.category == .cardiopulmonary }) {
                advisories.append("· 高龄患者心肺症状请直接向分诊护士说「有胸闷胸痛」，可争取分诊优先。")
            }
            advisories.append("· 请家属陪同，携带既往病历、正在服用的药物清单（含保健品）与医保卡。")
        }

        let plain: [String]
        switch spots.first?.region.urgencyFloor == .urgent ? .cardiopulmonary : main {
        case .cardiopulmonary:
            plain = ["胸口难受要马上看，别自己开车。", "把老怀表、戒指摘掉，方便抢救。"]
        case .digestive:
            plain = ["肚子疼要说清是哪个位置，像指方向盘一样指给医生看。"]
        case .neuro:
            plain = ["手麻、说话不清楚，抓紧时间，半小时内到医院才有得救。"]
        case .metabolic:
            plain = ["血糖计和药都带上，医生要看。"]
        default:
            plain = ["把不舒服的地方指给医生看，比说名字更有用。"]
        }

        return CarePathway(
            urgency: urgency,
            department: main.suggestedDepartment,
            departmentRationale: rationale(main: main, source: source, spots: spots),
            advisories: advisories,
            plainLanguage: plain
        )
    }

    private static func rationale(main: SymptomCategory, source: [NormalizedSegment], spots: [BodySpot]) -> String {
        var parts = ["本次描述以「\(main.rawValue)」相关症状为主（共 \(source.count) 项）"]
        if !spots.isEmpty {
            let where_ = spots.map(\.display).joined(separator: "、")
            parts.append("老人指认位置：\(where_)（\(spots.map { $0.region.doctorText }.joined(separator: "、"))）")
        }
        parts.append("\(main.suggestedDepartment) 接诊最快。")
        return parts.joined()
    }
}
