import Foundation

/// 路径评分：不是找「最短」，而是找「**伤情允许的最短**」。
struct RouteScorer {
    /// 返回 nil 表示这段路对该伤情**根本不能走**
    func score(_ segment: TerrainSegment, for injury: InjuryCase) -> Double? {
        // 脊柱/头颈伤：过不去台阶多的窄门，宁可绕远
        if injury == .spineSuspected || injury == .unconscious {
            if segment.steps > 0 && segment.narrowestCm < 80 { return nil }
            if segment.requiresSideways { return nil }
        }
        // 髋部骨折：伤腿要伸直，侧身或窄门必过不去
        if injury == .hipFracture, segment.requiresSideways { return nil }
        // 泥地 + 陡坡是所有重伤情的组合灾难
        if injury.isLifeThreatening, segment.surface == .mud, segment.slopePercent >= 15 { return nil }

        var score = 100.0
        score -= segment.slopePercent * 2.2
        score -= Double(segment.steps) * 6
        score -= max(0, 90 - segment.narrowestCm) * 0.4
        score -= segment.length * 0.25
        if segment.surface == .mud { score -= 12 }
        if segment.surface == .gravel, injury.isLifeThreatening { score -= 10 }
        if segment.surface == .tile, injury == .hipFracture { score -= 6 }
        return max(score, 0)
    }

    func bestRoute(from candidates: [TerrainSegment], for injury: InjuryCase) -> RouteChoice? {
        let viable = candidates.compactMap { segment -> (TerrainSegment, Double)? in
            guard let s = score(segment, for: injury) else { return nil }
            return (segment, s)
        }
        guard let top = viable.max(by: { $0.1 < $1.1 }) else { return nil }
        return RouteChoice(segment: top.0, score: top.1, rejectedCount: candidates.count - viable.count)
    }
}

struct RouteChoice: Hashable {
    let segment: TerrainSegment
    let score: Double
    /// 有多少条被否掉了——这个数字要告诉用户「我们已经帮你排除了几条危险的路」
    let rejectedCount: Int
}
