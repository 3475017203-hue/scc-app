import Foundation

/// 这一趟车会发生什么。核心判断只有一句话：
/// **乘客能不能"感觉到"下一站到了。**
enum RideRisk: String {
    case smooth = "顺利"
    case mightMiss = "可能坐过"
    case willLikelyMiss = "很可能坐过"
}

struct RidePlan {
    let risk: RideRisk
    /// 该在哪一站开始提醒
    let remindFromStopIndex: Int?
    let actions: [String]
    /// 震动节奏：越接近下车，越不一样
    let hapticName: String
}

/// 乘车提醒策略。
///
/// 真实的困难不是"不知道下一站叫什么"，而是
/// 老人耳背、车厢吵、报站太快——**所有 App 都假设能听见**。
struct RideCoach {
    /// 距离下车还有几站时开始提醒
    var remindStopsBefore: Int = 2

    func plan(route: Route, currentStopIndex: Int, destinationIndex: Int,
              canHearAnnouncements: Bool, lastStopHeard: Int?) -> RidePlan {
        guard destinationIndex > currentStopIndex else {
            return RidePlan(risk: .smooth, remindFromStopIndex: nil,
                            actions: ["已经过了目的站或快到了，下车前再看一眼站牌"], hapticName: "不提醒")
        }

        let stopsLeft = destinationIndex - currentStopIndex
        let start = max(currentStopIndex + 1, destinationIndex - remindStopsBefore)

        var actions: [String] = []
        let friction = route.stops[destinationIndex].friction

        if !canHearAnnouncements {
            actions.append("听不清报站：从现在开始每一站都会震动提醒")
            actions.append("看窗外店名、招牌颜色作为辅助确认")
        }
        switch friction {
        case .easy:
            break
        case .noSeat:
            actions.append("这一站没有座位，提前站起来准备，晚了可能挤不出去")
        case .noisy:
            actions.append("这一站噪声大，请盯着手机看，别只靠耳朵")
        case .crowdedTransfer:
            actions.append("到这一站要换乘，人多容易跟丢，跟着车上的换乘标识走")
        }

        // 报站没听见，是坐过站的直接原因
        if let last = lastStopHeard, last < currentStopIndex {
            actions.append("上一站报站可能没听见，请确认一下车还在不在下一站")
        }
        if stopsLeft <= 2 {
            actions.insert("下一站：\(route.stops[destinationIndex].name)", at: 0)
        }

        let risk: RideRisk
        if !canHearAnnouncements { risk = .willLikelyMiss }
        else if friction == .noisy || friction == .crowdedTransfer { risk = .mightMiss }
        else { risk = .smooth }

        return RidePlan(risk: risk, remindFromStopIndex: start, actions: actions,
                        hapticName: haptic(for: risk))
    }

 private func haptic(for risk: RideRisk) -> String {
        switch risk {
        case .smooth: "每站一下（轻）"
        case .mightMiss: "两下一组（中等）"
        case .willLikelyMiss: "三下一组，并在前一站连响（强）"
        }
    }
}
