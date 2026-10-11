import Foundation

/// 演示与测试用的"声音样本库"。
/// 每个样本既有**合成 PCM**（可跑通整条特征提取链路），
/// 也有一个人工标注的期望事件（用于测试）。
enum SignalLibrary {
    struct Sample {
        let name: String
        let event: SoundEvent
        let samples: [Float]
    }

    static func pcm(event: SoundEvent, duration: Double = 1.0) -> [Float] {
        let rate = 8_000
        let count = Int(rate * duration)
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / Double(rate)
            out[i] = wave(for: event, at: t)
        }
        return out
    }

    private static func wave(for event: SoundEvent, at t: Double) -> Float {
        let impulse: (Double) -> Float = { time in
            let phase = time.truncatingRemainder(dividingBy: 0.35)
            return phase < 0.04 ? Float(exp(-phase * 90)) : 0
        }
        switch event {
        case .knock:
            // 低频冲击 + 短噪声尾巴
            let body = sin(2 * .pi * 120 * t) * impulse(t)
            let tail = Float.random(in: -0.05...0.05) * exp(-(t.truncatingRemainder(dividingBy: 0.35)) * 60)
            return body + tail
        case .babyCry:
            // 700Hz 基频 + 5Hz 调制 + 高频噪声
            let mod = 0.5 + 0.5 * sin(2 * .pi * 5 * t)
            return Float(sin(2 * .pi * 700 * t) * mod * 0.5 + Float.random(in: -0.08...0.08) * mod)
        case .kettle:
            // 稳态高频噪声 + 缓慢上升
            let ramp = Float(min(1, t / 1.0))
            return Float.random(in: -0.4...0.4) * ramp
        case .smokeAlarm:
            // 3000Hz 方波，周期性开关
            let on = t.truncatingRemainder(dividingBy: 0.4) < 0.25
            guard on else { return 0 }
            return sin(2 * .pi * 3000 * t) > 0 ? 0.7 : -0.7
        case .waterLeak:
            return Float.random(in: -0.3...0.3)
        case .unknown:
            return Float.random(in: -0.1...0.1)
        }
    }

    static let demoSamples: [Sample] = [
        Sample(name: "有人敲门", event: .knock, samples: pcm(event: .knock)),
        Sample(name: "孩子在哭", event: .babyCry, samples: pcm(event: .babyCry)),
        Sample(name: "水烧开了", event: .kettle, samples: pcm(event: .kettle)),
        Sample(name: "烟雾报警器", event: .smokeAlarm, samples: pcm(event: .smokeAlarm))
    ]
}
