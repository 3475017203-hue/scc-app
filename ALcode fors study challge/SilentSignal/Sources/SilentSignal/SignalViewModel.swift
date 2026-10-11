import Foundation
import SwiftUI

@MainActor
final class SignalViewModel: ObservableObject {
    @Published private(set) var detections: [Detection] = []
    @Published private(set) var liveLevel: Double = -60
    @Published private(set) var isListening = false
    @Published var sensitivity: Sensitivity = .balanced {
        didSet { gate.sensitivity = sensitivity }
    }
    @Published private(set) var suppressedCount = 0
    @Published private(set) var location: SoundLocator.Location?

    let classifier = EventClassifier()
    private let player: HapticPlaying
    private let interferenceDetector = InterferenceDetector()
    private let locator = SoundLocator()
    private var gate = AlertGate()
    private var lastFeatures = AudioFeatures.quiet()

    init(player: HapticPlaying = SilentHapticPlayer()) {
        self.player = player
    }

    /// 喂一段 PCM 进来：算特征 → 分类 → 播放对应震动 → 记录
    @discardableResult
    func ingest(samples: [Float]) -> Detection {
        let features = FeatureExtractor.features(samples: samples)
        lastFeatures = features
        liveLevel = features.loudnessDB
        var classifier = self.classifier
        classifier.acceptanceThreshold = sensitivity.classificationThreshold
        let (event, confidence) = classifier.classify(features)
        let detection = Detection(event: event, confidence: confidence)

        let interference = interferenceDetector.classify(features)
        let admitted = gate.admit(event: event,
                                  confidence: confidence,
                                  interference: interference,
                                  severity: event.severity)
        if event != .unknown, !admitted { suppressedCount += 1 }
        if admitted {
            detections.insert(detection, at: 0)
            if detections.count > 30 { detections.removeLast() }
            player.play(HapticComposer.pattern(for: event))
        }
        return detection
    }

    /// 当前是否处在背景噪音里——UI 可据此提示用户调严
    var currentInterference: Interference? {
        interferenceDetector.classify(lastFeatures)
    }

    /// 有双通道输入时才给方位；单通道时 locator 会自己说明为什么给不出
    func locate(level: SoundLocator.ChannelLevel?, loudnessDB: Double, hasStereoInput: Bool) {
        location = locator.locate(level: level, loudnessDB: loudnessDB, hasStereoInput: hasStereoInput)
    }

    func replayHaptic(for event: SoundEvent) {
        player.play(HapticComposer.pattern(for: event))
    }

    func runDemo() {
        for sample in SignalLibrary.demoSamples {
            ingest(samples: sample.samples)
        }
    }

    func clear() {
        detections = []
        gate.reset()
    }

    /// 紧急度最高的一条 —— 首页只展示这一条
    var mostUrgent: Detection? {
        detections.max { $0.event.severity < $1.event.severity }
    }
}
