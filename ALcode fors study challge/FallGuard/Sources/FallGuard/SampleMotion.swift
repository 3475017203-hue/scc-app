import Foundation

/// 合成运动样本，供演示与测试共用。
enum SampleMotion {
    /// 日常走动：模长在 1g 上下小幅波动
    static func walking(seconds: Double = 2, sampleRate: Double = 50) -> [AccelSample] {
        build(seconds: seconds, sampleRate: sampleRate) { t in
            let wobble = 0.25 * sin(2 * .pi * 2.2 * t)
            return AccelSample(x: 0.3 + wobble, y: 0.1, z: 0.95)
        }
    }

    /// 摔倒后躺着不动：模长贴近 1g 且几乎无波动
    static func lyingStill(seconds: Double = 30, sampleRate: Double = 50) -> [AccelSample] {
        build(seconds: seconds, sampleRate: sampleRate) { _ in
            AccelSample(x: 0.02, y: 0.01, z: 1.0)
        }
    }

    /// 摔一下自己爬起来：冲击之后很快有动作
    static func fallAndRecover(sampleRate: Double = 50) -> [AccelSample] {
        var out = walking(seconds: 1, sampleRate: sampleRate)
        out += [AccelSample(x: 0.1, y: 0.1, z: 0.2)]
        out += [AccelSample(x: 3.6, y: 0.4, z: 2.4)]
        out += build(seconds: 1.5, sampleRate: sampleRate) { t in
            AccelSample(x: 0.9 * sin(2 * .pi * 3 * t), y: 0.4, z: 0.8)
        }
        out += lyingStill(seconds: 4, sampleRate: sampleRate)
        return out
    }

    /// 真跌倒：失重 → 撞击 → 长时间不动
    static func fallAndStill(sampleRate: Double = 50) -> [AccelSample] {
        var out = walking(seconds: 1, sampleRate: sampleRate)
        out += [AccelSample(x: 0.05, y: 0.05, z: 0.25)]
        out += [AccelSample(x: 4.2, y: 0.6, z: 3.1)]
        out += lyingStill(seconds: 40, sampleRate: sampleRate)
        return out
    }

    private static func build(seconds: Double, sampleRate: Double, generator: (Double) -> AccelSample) -> [AccelSample] {
        let count = Int(seconds * sampleRate)
        return (0..<count).map { generator(Double($0) / sampleRate) }
    }
}
