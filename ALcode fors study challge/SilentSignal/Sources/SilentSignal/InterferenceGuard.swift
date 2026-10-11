import Foundation

/// 家里的背景声：不是所有「声音事件」都值得叫人起床。
enum Interference: String, CaseIterable {
    case music
    case speech
    case appliance
    case traffic
    case unknown

    var label: String {
        switch self {
        case .music: "背景音乐/电视声"
        case .speech: "说话声"
        case .appliance: "家电持续噪音"
        case .traffic: "窗外车流"
        case .unknown: "未知干扰"
        }
    }
}

/// 干扰识别：稳态是家电与车流的特征；强起伏但不规则是音乐与人声的特征。
/// 与事件分类器共用同一套声学特征，不额外占用算力。
struct InterferenceDetector {
    func classify(_ f: AudioFeatures) -> Interference? {
        guard f.loudnessDB > -55 else { return nil }

        if f.envelopeModulation < 1.15, f.impacts == 0, f.brightness < 0.5 {
            return f.loudnessDB > -25 ? .appliance : .traffic
        }
        if f.envelopeModulation > 2.0, f.brightness > 0.45, f.brightness < 0.9 {
            return f.crestFactor < 6 ? .music : .speech
        }
        return nil
    }
}
