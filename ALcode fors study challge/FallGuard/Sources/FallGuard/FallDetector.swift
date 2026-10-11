import Foundation

/// 三轴加速度采样点（g）。
struct AccelSample: Hashable {
    let x: Double
    let y: Double
    let z: Double
    var magnitude: Double { sqrt(x * x + y * y + z * z) }
}

enum FallPhase: String {
    case idle = "日常活动"
    case needHelp = "需要帮助"
    case recovered = "自己起来了"
}

struct FallVerdict: Hashable {
    let isFall: Bool
    let phase: FallPhase
    /// 撞击强度（g 的倍数）
    let impactG: Double
    /// 撞击后连续静止了多少秒
    let stillnessSeconds: Double
    /// 判断依据，必须能解释给人听
    let reasons: [String]
}

/// 跌倒检测：**冲击 + 之后的静止**才算一次需要帮助的跌倒。
/// 这两个条件缺一不可，也正是很多产品做错的地方——
/// 只看冲击，放下手机也会响；只看冲击，人摔一下自己爬起来也会呼救。
struct FallDetector {
    var impactThresholdG: Double = 2.5
    var freeFallThresholdG: Double = 0.5
    var stillnessThresholdSeconds: Double = 25
    var stillnessThresholdG: Double = 0.12

    func verdict(samples: [AccelSample], sampleRate: Double = 50) -> FallVerdict {
        guard samples.count > 10 else {
            return FallVerdict(isFall: false, phase: .idle, impactG: 0, stillnessSeconds: 0, reasons: ["采样不足"])
        }

        var peak = 0.0
        var peakIndex = 0
        var sawFreeFall = false
        for (i, sample) in samples.enumerated() {
            let g = sample.magnitude
            if g < freeFallThresholdG { sawFreeFall = true }
            if g > peak { peak = g; peakIndex = i }
        }

        guard peak >= impactThresholdG else {
            let msg = "最大冲击 \(String(format: "%.1f", peak))g，未达到阈值"
            return FallVerdict(isFall: false, phase: .idle, impactG: peak, stillnessSeconds: 0, reasons: [msg])
        }

        var reasons: [String] = []
        if sawFreeFall { reasons.append("检测到失重瞬间") }
        reasons.append("冲击 \(String(format: "%.1f", peak))g，超过阈值")

        let stillness = measureStillness(samples.dropFirst(peakIndex), sampleRate: sampleRate)
        if stillness >= stillnessThresholdSeconds {
            reasons.append("撞击后静止 \(Int(stillness)) 秒")
            return FallVerdict(isFall: true, phase: .needHelp, impactG: peak, stillnessSeconds: stillness, reasons: reasons)
        }
        reasons.append("撞击后很快有动作，判断为自行起身")
        return FallVerdict(isFall: true, phase: .recovered, impactG: peak, stillnessSeconds: stillness, reasons: reasons)
    }

    /// 手机静止躺着时模长约等于 1g；用「与 1g 的偏差」判断静不静。
    private func measureStillness(_ samples: ArraySlice<AccelSample>, sampleRate: Double) -> Double {
        var run: Double = 0
        var best: Double = 0
        for sample in samples {
            if abs(sample.magnitude - 1.0) < stillnessThresholdG {
                run += 1 / sampleRate
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best
    }
}
