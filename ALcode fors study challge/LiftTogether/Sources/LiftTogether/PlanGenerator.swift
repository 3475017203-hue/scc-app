import Foundation

/// 分工。混乱的现场最缺的不是知识，是「谁干什么」。
enum TeamRole: String, CaseIterable, Identifiable, Codable {
    case headHolder = "1 号：托住头颈，保持不转"
    case torsoHolder = "2 号：托肩背与腰"
    case legHolder = "3 号：托双腿，伤腿保持原位"
    case coordinator = "指挥：喊口令，数三下再一起动"

    var id: String { rawValue }
}

/// 一份能在救护车到达前执行完的搬运方案。
struct MovePlan {
    let injury: InjuryCase
    let route: RouteChoice?
    let people: [TeamRole]
    let steps: [String]
    let doNot: [String]
    let whileWaiting: [String]
    let hasEnoughPeople: Bool

    /// 一句话结论：够人就走，不够人先叫人、先清障
    var headline: String {
        if !hasEnoughPeople {
            return "人手不够，需要 \(injury.minimumPeople) 人。先别硬抬，先去叫人、先清通道。"
        }
        if let route {
            return "\(injury.minimumPeople) 人，走「\(route.segment.name)」，另外 \(route.rejectedCount) 条更短但危险的路已经排除。"
        }
        return "没有一条路对这种伤情是安全的。先别动患者，等专业人员。"
    }
}

struct PlanGenerator {
    func plan(for injury: InjuryCase, segments: [TerrainSegment], availablePeople: Int) -> MovePlan {
        let choice = RouteScorer().bestRoute(from: segments, for: injury)
        let needed = injury.minimumPeople

        let roles: [TeamRole]
        switch injury {
        case .minor:
            roles = [.coordinator]
        case .bleeding, .legInjury:
            roles = [.coordinator, .torsoHolder]
        case .hipFracture, .unconscious:
            roles = [.coordinator, .torsoHolder, .legHolder]
        case .spineSuspected:
            roles = [.coordinator, .headHolder, .torsoHolder, .legHolder]
        }

        return MovePlan(
            injury: injury,
            route: choice,
            people: roles,
            steps: steps(for: injury, route: choice),
            doNot: injury.contraindications,
            whileWaiting: injury.waitingActions,
            hasEnoughPeople: availablePeople >= needed
        )
    }

    private func steps(for injury: InjuryCase, route: RouteChoice?) -> [String] {
        guard let route else {
            return ["保持现场，不要随意搬动", "持续观察呼吸与出血"]
        }
        let segment = route.segment
        var result: [String] = []

        switch injury.handling {
        case .keepAxis:
            result.append("全员就位后，指挥喊「一、二、三」，同时把伤者平移到硬板上")
        case .keepLegStraight:
            result.append("伤腿与身体保持一条直线，用衣物把两腿夹住固定")
        case .pressureThenMove:
            result.append("先按压止血至少 10 分钟，再讨论怎么移")
        case .dragByClothing:
            result.append("抓伤者腋下的衣物平拖，不要拉伤肢")
        case .selfWalk:
            result.append("搀扶腋下，让伤者自己发力")
        }

        result.append("经过「\(segment.name)」：\(describe(segment))")
        if let note = segment.surface.frictionNote {
            result.append(note)
        }
        return result
    }

    private func describe(_ segment: TerrainSegment) -> String {
        var parts: [String] = ["\(Int(segment.length)) 米"]
        if segment.slopePercent >= 1 { parts.append("坡度 \(Int(segment.slopePercent))%") }
        if segment.steps > 0 { parts.append("\(segment.steps) 级台阶") }
        if segment.narrowestCm < 90 { parts.append("最窄 \(Int(segment.narrowestCm)) 厘米，注意两侧") }
        if segment.requiresSideways { parts.append("必须侧身") }
        return parts.joined(separator: "，")
    }
}
