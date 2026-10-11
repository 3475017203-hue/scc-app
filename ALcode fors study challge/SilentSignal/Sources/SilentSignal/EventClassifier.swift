import Foundation

/// 规则分类器：把声学特征映射成「这是敲门 / 哭 / 水开 / 报警」。
///
/// 为什么用可解释的规则而不是只靠模型：
/// 听障家庭的误报代价很高——每次误报都要爬起来去看，
/// 几次之后人就不信这个设备了。所以每条判定都写明依据，
/// 并且低于阈值时**宁可报「不确定」也不硬猜**。
struct EventClassifier {
    /// 低于这个置信度就返回 .unknown，宁可漏报也不让用户白跑一趟
    var acceptanceThreshold: Double = 0.55

    enum Feature: Hashable {
        case loudness, brightness, modulation, impacts, crest
    }

    func classify(_ f: AudioFeatures) -> (SoundEvent, Double) {
        guard f.loudnessDB > -45 else { return (.unknown, 0) }   // 太安静，不是事件

        let observed: [Feature: Double] = [
            .loudness: min(max((f.loudnessDB + 60) / 60, 0), 1),
            .brightness: f.brightness,
            .modulation: min(f.envelopeModulation / 4, 1),
            .impacts: min(f.impacts / 4, 1),
            .crest: min(max((f.crestFactor - 1) / 12, 0), 1)
        ]

        var scores: [(SoundEvent, Double)] = []
        scores.append((.knock, similarity(observed, target: [.loudness: 0.7, .brightness: 0.25, .modulation: 0.75, .impacts: 0.8, .crest: 0.9])))
        scores.append((.babyCry, similarity(observed, target: [.loudness: 0.65, .brightness: 0.8, .modulation: 0.9, .impacts: 0.15, .crest: 0.5])))
        scores.append((.kettle, similarity(observed, target: [.loudness: 0.55, .brightness: 0.7, .modulation: 0.25, .impacts: 0.1, .crest: 0.35])))
        scores.append((.waterLeak, similarity(observed, target: [.loudness: 0.5, .brightness: 0.5, .modulation: 0.55, .impacts: 0.45, .crest: 0.5])))

        // 烟雾报警：响、亮、稳态，再加周期性重复的加分
        var alarm = similarity(observed, target: [.loudness: 0.9, .brightness: 0.75, .modulation: 0.2, .impacts: 0.05, .crest: 0.3])
        if f.isPeriodic { alarm = min(1, alarm + 0.25) }
        scores.append((.smokeAlarm, alarm))

        let best = scores.max { $0.1 < $1.1 }!
        guard best.1 >= acceptanceThreshold else { return (.unknown, best.1) }
        return best
    }

    /// 加权欧氏距离 → 0…1 相似度
    private func similarity(_ observed: [Feature: Double], target: [Feature: Double]) -> Double {
        var sum = 0.0
        for (key, goal) in target {
            let value = observed[key] ?? 0
            sum += pow(value - goal, 2)
        }
        return max(0, 1 - sqrt(sum) / 1.6)
    }
}
