import Foundation
#if canImport(CoreHaptics)
import CoreHaptics
#endif

/// 每种事件设计一种「能被摸懂」的震动节奏。
///
/// 关键洞察：**震动传不了语义**。所以设计原则是
/// 「紧急度 = 强度 + 重复次数」，
/// 让用户不看手机也能判断「要不要现在爬起来」。
struct HapticPattern: Hashable {
    /// 相对时间（秒）与强度（0…1）
    struct Tap: Hashable {
        let time: Double
        let intensity: Double
    }

    let event: SoundEvent
    let taps: [Tap]

    var totalDuration: Double { (taps.last?.time ?? 0) + 0.15 }
    var totalIntensity: Double { taps.reduce(0) { $0 + $1.intensity } }
}

enum HapticComposer {
    static func pattern(for event: SoundEvent) -> HapticPattern {
        switch event {
        case .knock:
            // 两短一长：与敲门节奏同构，不用看也知道是「有人敲门」
            return HapticPattern(event: event, taps: [
                .init(time: 0.00, intensity: 0.55),
                .init(time: 0.14, intensity: 0.55),
                .init(time: 0.34, intensity: 0.85)
            ])
        case .babyCry:
            // 连续轻颤：像摇晃，频率高但不重
            return HapticPattern(event: event, taps: (0..<8).map {
                .init(time: Double($0) * 0.12, intensity: 0.35)
            })
        case .kettle:
            // 由弱到强逐渐急促：提醒「该过去了」，但不惊吓
            return HapticPattern(event: event, taps: (0..<5).map { i in
                .init(time: Double(i) * (0.22 - Double(i) * 0.02), intensity: 0.3 + Double(i) * 0.1)
            })
        case .smokeAlarm:
            // 长-长-长，最强：半夜也能把人震醒
            return HapticPattern(event: event, taps: [
                .init(time: 0.00, intensity: 1.0),
                .init(time: 0.45, intensity: 1.0),
                .init(time: 0.90, intensity: 1.0)
            ])
        case .waterLeak:
            // 急促连续：像水滴连珠
            return HapticPattern(event: event, taps: (0..<6).map {
                .init(time: Double($0) * 0.09, intensity: 0.7)
            })
        case .unknown:
            // 两下轻拍 + 一次长：明确的「有东西，但你得去看一眼」
            return HapticPattern(event: event, taps: [
                .init(time: 0.00, intensity: 0.3),
                .init(time: 0.20, intensity: 0.3),
                .init(time: 0.50, intensity: 0.45)
            ])
        }
    }
}

/// 震动播放抽象：Playgrounds 与真机 CoreHaptics 都走同一接口。
protocol HapticPlaying: AnyObject {
    func play(_ pattern: HapticPattern)
}

final class CoreHapticPlayer: HapticPlaying {
    func play(_ pattern: HapticPattern) {
        #if canImport(CoreHaptics)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        var events: [CHHapticEvent] = pattern.taps.map { tap in
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(tap.intensity))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(tap.intensity))
            return CHHapticEvent(eventType: .hapticTransient,
                                 parameters: [intensity, sharpness],
                                 relativeTime: tap.time)
        }
        events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [],
                                     relativeTime: pattern.totalDuration, duration: 0.05))
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            let player = try engine.makePlayer(with: try CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: 0)
        } catch {
            // 播放失败不该影响听音流程，静默降级
        }
        #else
        _ = pattern
        #endif
    }
}

final class SilentHapticPlayer: HapticPlaying {
    func play(_ pattern: HapticPattern) { _ = pattern }
}
