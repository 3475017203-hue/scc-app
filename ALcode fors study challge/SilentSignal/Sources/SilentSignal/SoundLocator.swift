import Foundation

/// 声音从哪来、多远——这是竞品 Vigilant Ear 打出的牌，我们原本没有。
///
/// 但这里必须诚实：**单麦克风在物理上无法可靠判定方向**。
/// 所以本作品只在"真的具备双通道输入"时给出方位，
/// 单通道时**返回 nil 并说明原因**，而不是给一个听起来很确定的假方位。
struct SoundLocator {
    enum Bearing: String {
        case front = "正前方"
        case frontLeft = "左前方"
        case frontRight = "右前方"
        case left = "正左"
        case right = "正右"
        case behind = "身后"
        case unknown = "方位未知"
    }

    enum DistanceBand: String {
        case veryNear = "很近，就在旁边"
        case near = "同一间屋"
        case midRange = "隔壁或楼上楼下"
        case far = "较远"
        case unknown = "距离无法判断"
    }

    struct Location {
        let bearing: Bearing?
        let distanceBand: DistanceBand
        /// 0…1，够低就说明别拿它当依据
        let confidence: Double
        /// 不能给出方位时，说明白为什么
        let caveat: String?

        var bearingText: String { bearing?.rawValue ?? Bearing.unknown.rawValue }
        var distanceText: String { distanceBand.rawValue }
    }

    /// 单个通道的能量（dBFS）
    struct ChannelLevel {
        let left: Double
        let right: Double
    }

    /// 判定方位所需的双通道能量差（dB）。经验值：
    /// 声源偏离中心时，靠近声源一侧的麦克风会明显更响。
    var bearingThresholdDB: Double = 4.0

    func locate(level: ChannelLevel?, loudnessDB: Double, hasStereoInput: Bool) -> Location {
        let distance = distanceBand(forLoudness: loudnessDB)

        guard hasStereoInput, let level = level else {
            return Location(
                bearing: nil,
                distanceBand: distance,
                confidence: 0.25,
                caveat: "只有一个麦克风时，物理上无法判定方向。这里的距离也只是粗略分档，别当成尺子用。"
            )
        }

        let delta = level.left - level.right
        guard abs(delta) >= bearingThresholdDB else {
            return Location(bearing: .front, distanceBand: distance,
                            confidence: 0.5,
                            caveat: delta < bearingThresholdDB ? nil : "左右差异太小，判定为正前方。" as String?)
        }
        let bearing: Bearing = delta > 0 ? .left : .right
        let confidence = min(0.9, 0.45 + abs(delta) / 20)
        return Location(bearing: bearing, distanceBand: distance,
                        confidence: confidence, caveat: nil)
    }

    /// 三档粗分：音量只能给出很粗的距离感，真正可靠的是直达声与混响比，
    /// 而后者需要麦克风阵列。这里不假装更精确。
    func distanceBand(forLoudness loudnessDB: Double) -> DistanceBand {
        switch loudnessDB {
        case ..<(-20): return .veryNear
        case (-20)..<(-30): return .near
        case (-30)..<(-42): return .midRange
        default: return .far
        }
    }
}
