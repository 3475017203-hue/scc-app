import Foundation

/// 一段声音的声学特征。全部可在设备端从 PCM 算出，几十行就能跑，
/// 且**完全可解释**——每条判断都能指回具体的物理量。
struct AudioFeatures: Hashable {
    /// 音量（dBFS，0…-60）
    var loudnessDB: Double
    /// 频谱明亮度（归一化 0…1）：低 = 闷（敲击/水），高 = 尖（警报/哭）
    var brightness: Double
    /// 过零率：噪声越多越高
    var zeroCrossingRate: Double
    /// 峰值因数：冲击声（敲门）瞬时能量极高，稳态声接近 1
    var crestFactor: Double
    /// 包络起伏比：哭声一鼓一鼓，比值大
    var envelopeModulation: Double
    /// 冲击次数（敲门约 2–4 次）
    var impacts: Double
    /// 是否呈周期性重复（报警器一轮接一轮）
    var isPeriodic: Bool

    static func quiet() -> AudioFeatures {
        AudioFeatures(loudnessDB: -50, brightness: 0, zeroCrossingRate: 0,
                       crestFactor: 1, envelopeModulation: 1, impacts: 0, isPeriodic: false)
    }

    /// 特征之间的差异度，用于"这个声音有多不像我认识的那些"
    func distance(to other: AudioFeatures) -> Double {
        let dz = (loudnessDB - other.loudnessDB) / 20
        let db = brightness - other.brightness
        let dm = envelopeModulation - other.envelopeModulation
        let di = impacts - other.impacts
        let dc = crestFactor / max(other.crestFactor, 0.1)
        return sqrt(dz * dz + db * db + dm * dm * 0.5 + di * di * 0.25 + (dc - 1) * (dc - 1) * 0.2)
    }
}

/// 从 PCM 采样算特征。独立成文件，便于将来换成 SoundAnalysis 的输出。
enum FeatureExtractor {
    static func features(samples: [Float]) -> AudioFeatures {
        guard samples.count > 64 else { return .quiet() }

        let rms = sqrt(samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count))
        let loudnessDB = 20 * log10(max(rms, 1e-9))

        var crossings = 0
        for i in 1..<samples.count where (samples[i] >= 0) != (samples[i - 1] >= 0) {
            crossings += 1
        }
        let zcr = Double(crossings) / Double(samples.count)

        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        let crest = peak > 0 ? Double(peak) / max(Double(rms), 1e-9) : 1

        let env = envelope(samples, window: 256)
        let modulation = modulationRatio(env)
        let impacts = countImpacts(env)
        let brightness = brightnessIndex(samples)
        let periodic = isPeriodicPattern(env)

        return AudioFeatures(loudnessDB: loudnessDB,
                             brightness: brightness,
                             zeroCrossingRate: zcr,
                             crestFactor: crest,
                             envelopeModulation: modulation,
                             impacts: impacts,
                             isPeriodic: periodic)
    }

    static func envelope(_ samples: [Float], window: Int) -> [Double] {
        stride(from: 0, to: samples.count, by: window).map { start in
            let slice = samples[start..<min(start + window, samples.count)]
            let rms = sqrt(slice.reduce(0.0) { $0 + Double($1 * $1) } / Double(slice.count))
            return rms
        }
    }

    /// 起伏比：max / mean，越大越像"一鼓一鼓"
    static func modulationRatio(_ env: [Double]) -> Double {
        let mean = env.reduce(0, +) / Double(max(env.count, 1))
        guard mean > 1e-9 else { return 1 }
        return (env.max() ?? mean) / mean
    }

    /// 冲击计数：包络显著跃升
    static func countImpacts(_ env: [Double]) -> Double {
        guard env.count > 2 else { return 0 }
        var impacts = 0.0
        for i in 1..<(env.count - 1) {
            let rise = env[i] / max(env[i - 1], 1e-9)
            let fall = env[i] / max(env[i + 1], 1e-9)
            if rise > 2.0 && fall > 1.3 && env[i] > 1e-3 { impacts += 1 }
        }
        return impacts
    }

    /// 明亮度 0…1：高频成分占比越高越亮
    static func brightnessIndex(_ samples: [Float]) -> Double {
        var fast = 0.0
        var slow = 0.0
        for i in 1..<samples.count {
            let d = abs(Double(samples[i] - samples[i - 1]))
            fast += d
            slow += abs(Double(samples[i]))
        }
        guard slow > 0 else { return 0 }
        return min(max(fast / slow / 2, 0), 1)
    }

    static func isPeriodicPattern(_ env: [Double]) -> Bool {
        guard env.count >= 8 else { return false }
        let mean = env.reduce(0, +) / Double(env.count)
        guard mean > 1e-9 else { return false }
        let first = env.prefix(env.count / 2).map { $0 / mean }
        let second = env.dropFirst(env.count / 2).map { $0 / mean }
        let matches = zip(first, second).filter { abs($0 - $1) < 0.35 }.count
        return Double(matches) / Double(max(first.count, 1)) > 0.7
    }
}
