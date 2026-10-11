import Foundation

struct HapticPattern {
    struct Tap: Hashable {
        let time: Double
        let intensity: Double
    }
}

/// 三种提醒节奏，让不看手机的人也知道「该吃了」还是「出事了」。
enum DoseHaptic {
    case due
    case overdue
    case urgent

    var patternName: String {
        switch self {
        case .due: "短-短-停"
        case .overdue: "短-短-停（更慢、更沉）"
        case .urgent: "长-长-长"
        }
    }

    func pattern() -> [HapticPattern.Tap] {
        switch self {
        case .due:
            return [.init(time: 0.00, intensity: 0.4), .init(time: 0.25, intensity: 0.4)]
        case .overdue:
            return [.init(time: 0.00, intensity: 0.7), .init(time: 0.45, intensity: 0.7)]
        case .urgent:
            return [.init(time: 0.00, intensity: 1.0), .init(time: 0.5, intensity: 1.0), .init(time: 1.0, intensity: 1.0)]
        }
    }
}

/// 震动播放抽象（Playgrounds 与真机同一接口）
protocol DoseHapticPlaying: AnyObject {
    func play(_ taps: [HapticPattern.Tap])
}

final class SilentDoseHapticPlayer: DoseHapticPlaying {
    func play(_ taps: [HapticPattern.Tap]) { _ = taps }
}
