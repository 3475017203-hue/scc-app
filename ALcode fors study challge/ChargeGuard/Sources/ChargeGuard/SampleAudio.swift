import Foundation

enum SampleAudio {
    /// 正常充电：规律的低频脉冲
    static func normalPulse(seconds: Double = 1, sampleRate: Double = 8_000) -> [Float] {
        build(seconds: seconds, sampleRate: sampleRate) { t in
            let on = t.truncatingRemainder(dividingBy: 0.5) < 0.2
            guard on else { return 0 }
            return Float(sin(2 * .pi * 220 * t) * 0.25)
        }
    }

    /// 老化充电器：持续的高频啸叫
    static func whine(seconds: Double = 1, sampleRate: Double = 8_000) -> [Float] {
        build(seconds: seconds, sampleRate: sampleRate) { t in
            Float(sin(2 * .pi * 4_200 * t) * 0.22 + Float.random(in: -0.02...0.02))
        }
    }

    /// 噼啪声：密集短冲击
    static func crackle(seconds: Double = 1, sampleRate: Double = 8_000) -> [Float] {
        build(seconds: seconds, sampleRate: sampleRate) { t in
            let phase = t.truncatingRemainder(dividingBy: 0.06)
            if phase < 0.006 { return Float.random(in: -0.5...0.5) }
            return Float.random(in: -0.03...0.03)
        }
    }

    static func signature(for kind: Kind, reportedSmell: Bool = false) -> ChargeSignature {
        switch kind {
        case .normal:
            return ChargeSignature(loudnessDB: -22, crackleRate: 0.5, whineLevel: 0.1,
                                  isRegularPulse: true, reportedSmell: reportedSmell)
        case .aging:
            return ChargeSignature(loudnessDB: -26, crackleRate: 1, whineLevel: 0.45,
                                  isRegularPulse: true, reportedSmell: reportedSmell)
        case .suspect:
            return ChargeSignature(loudnessDB: -20, crackleRate: 15, whineLevel: 0.2,
                                  isRegularPulse: false, reportedSmell: reportedSmell)
        case .dangerous:
            return ChargeSignature(loudnessDB: -16, crackleRate: 26, whineLevel: 0.3,
                                  isRegularPulse: false, reportedSmell: true)
        }
    }

    enum Kind { case normal, aging, suspect, dangerous }

    private static func build(seconds: Double, sampleRate: Double, generator: (Double) -> Float) -> [Float] {
        let count = Int(seconds * sampleRate)
        return (0..<count).map { generator(Double($0) / sampleRate) }
    }
}
