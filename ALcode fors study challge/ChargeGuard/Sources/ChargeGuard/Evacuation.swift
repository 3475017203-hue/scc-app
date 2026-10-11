import Foundation

/// 楼道的现实：楼道被电动车占满、门被堵住、烟雾往下走。
/// 所以疏散指引必须解决两个问题：**先叫谁、从哪边走**。
struct Building {
    let name: String
    let floors: Int
    /// 从楼道口到每一层的距离（米），索引 0 = 一层
    let corridorLengths: [Double]
    /// 楼道是否被占用（停放车辆、堆物）
    let corridorBlocked: Bool
    /// 是否有电梯（火灾时不可用）
    let hasElevator: Bool
}

struct EvacuationRoute {
    let steps: [String]
    let warnings: [String]
    let estimatedSeconds: Double
}

struct EvacuationPlanner {
    /// 步行速度（米/秒），保守取值
    var walkingSpeed: Double = 0.8

    func route(from floor: Int, in building: Building) -> EvacuationRoute {
        var steps: [String] = []
        var warnings: [String] = []

        steps.append("先喊人：\(building.name)，\(floor) 层有情况，麻烦一起下楼。")
        steps.append("不要坐电梯\(building.hasElevator ? "（虽然有电梯，火灾时不能用）" : "（本楼无电梯）")。")

        if building.corridorBlocked {
            warnings.append("楼道被占用：先挪开挡道的车辆与杂物，不要点火、不要硬推。")
        }

        steps.append("湿毛巾捂住口鼻，弯腰低姿前进，烟往下走。")

        if let distance = distance(from: floor, in: building) {
            let seconds = distance / max(walkingSpeed, 0.1)
            steps.append("到楼外大约需要 \(Int(seconds)) 秒（按 \(building.name) 的实际楼道长度估算）。")
        }

        steps.append("到室外后拨打 119，说清楼栋、楼层、有没有被困住的人。")

        if floor > 1 && building.corridorBlocked {
            warnings.append("高楼层 + 楼道堵塞 = 最危险组合。这一条值得单独记在楼道张贴的疏散提示上。")
        }
        return EvacuationRoute(steps: steps, warnings: warnings, estimatedSeconds: seconds(from: floor, in: building))
    }

    private func distance(from floor: Int, in building: Building) -> Double? {
        guard floor >= 1, floor <= building.corridorLengths.count + 1 else { return nil }
        return floor <= 1 ? building.corridorLengths.first : building.corridorLengths.prefix(floor - 1).reduce(0, +)
    }

    private func seconds(from floor: Int, in building: Building) -> Double {
        (distance(from: floor, in: building) ?? 0) / max(walkingSpeed, 0.1)
    }
}
