import Foundation

/// 用户可调的严格程度。
/// 误报的代价是「爬起来看一眼」，几次之后就不信这个设备了——
/// 所以宁可调严，让用户自己决定值不值得。
enum Sensitivity: String, CaseIterable, Identifiable {
    case strict = "严格"
    case balanced = "均衡"
    case relaxed = "宽松"

    var id: String { rawValue }

    /// 触发所需的连续确认次数（危险事件永远只要 1 次）
    var requiredConsecutiveHits: Int {
        switch self {
        case .strict: 3
        case .balanced: 2
        case .relaxed: 1
        }
    }

    var classificationThreshold: Double {
        switch self {
        case .strict: 0.68
        case .balanced: 0.55
        case .relaxed: 0.45
        }
    }
}

/// 告警闸门：去抖动 + 干扰抑制。
/// 这是「让用户信得过这个设备」的核心装置——两道闸门都可能放过真警报，
/// 但都会拦掉绝大多数误报。
struct AlertGate {
    var sensitivity: Sensitivity = .balanced
    var suppressesInterference = true

    private(set) var streak: [SoundEvent: Int] = [:]

    /// 是否应该真的震动提醒
    mutating func admit(event: SoundEvent,
                        confidence: Double,
                        interference: Interference?,
                        severity: SoundEvent.Severity) -> Bool {
        guard event != .unknown else {
            streak = [:]
            return false
        }
        guard confidence >= sensitivity.classificationThreshold else { return false }

        // 紧急事件不参与去抖动：宁可信一次，也不漏一次
        if severity == .critical {
            streak = [:]
            return true
        }

        if suppressesInterference, let interference, interference != .unknown {
            streak = [:]
            return false
        }

        streak[event] = (streak[event] ?? 0) + 1
        return (streak[event] ?? 0) >= sensitivity.requiredConsecutiveHits
    }

    mutating func reset() { streak = [:] }
}
