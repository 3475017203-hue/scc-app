import XCTest
@testable import SilentSignal

final class EventClassifierTests: XCTestCase {
    private let classifier = EventClassifier()

    private func features(loudness: Double, brightness: Double, modulation: Double,
                          impacts: Double, crest: Double, periodic: Bool = false) -> AudioFeatures {
        AudioFeatures(loudnessDB: loudness, brightness: brightness, zeroCrossingRate: 0.1,
                      crestFactor: crest, envelopeModulation: modulation,
                      impacts: impacts, isPeriodic: periodic)
    }

    func testKnockPattern() {
        let f = features(loudness: -18, brightness: 0.2, modulation: 3.2, impacts: 3, crest: 10)
        let (event, confidence) = classifier.classify(f)
        XCTAssertEqual(event, .knock)
        XCTAssertGreaterThan(confidence, 0.55)
    }

    func testBabyCryPattern() {
        let f = features(loudness: -20, brightness: 0.82, modulation: 3.6, impacts: 0, crest: 4)
        XCTAssertEqual(classifier.classify(f).0, .babyCry)
    }

    func testKettleSteadyHigh() {
        let f = features(loudness: -22, brightness: 0.72, modulation: 0.9, impacts: 0, crest: 2)
        XCTAssertEqual(classifier.classify(f).0, .kettle)
    }

    func testSmokeAlarmPeriodicBoost() {
        let steady = features(loudness: -8, brightness: 0.78, modulation: 0.7, impacts: 0, crest: 1.5)
        let periodic = AudioFeatures(loudnessDB: -8, brightness: 0.78, zeroCrossingRate: 0.4,
                                      crestFactor: 1.5, envelopeModulation: 0.7,
                                      impacts: 0, isPeriodic: true)
        let a = classifier.classify(steady).1
        let b = classifier.classify(periodic).1
        XCTAssertEqual(classifier.classify(periodic).0, .smokeAlarm)
        XCTAssertGreaterThan(b, a)
    }

    /// 关键的行为约定：不确定就说不确定，宁可漏报也不让用户白爬起来。
    func testAmbiguousSoundIsNotGuessed() {
        let f = features(loudness: -20, brightness: 0.5, modulation: 1.4, impacts: 1, crest: 3)
        XCTAssertEqual(classifier.classify(f).0, .unknown)
    }

    func testQuietRoomYieldsNothing() {
        XCTAssertEqual(classifier.classify(AudioFeatures.quiet()).0, .unknown)
    }

    func testNoFalseAlarmOnWhiteNoise() {
        let samples = SignalLibrary.pcm(event: .waterLeak, duration: 0.6)
        let detection = classifier.classify(FeatureExtractor.features(samples: samples))
        // 白噪声即便被听到，也绝不该被说成"烟雾报警器"
        XCTAssertNotEqual(detection.0, .smokeAlarm)
    }
}

final class HapticComposerTests: XCTestCase {
    func testKnockUsesShortLongLong() {
        let pattern = HapticComposer.pattern(for: .knock)
        XCTAssertEqual(pattern.taps.count, 3)
        XCTAssertGreaterThan(pattern.taps[2].intensity, pattern.taps[0].intensity)
    }

    /// 紧急度必须体现为强度：烟警必须比敲门重。
    func testSeverityMapsToIntensity() {
        let alarm = HapticComposer.pattern(for: .smokeAlarm)
        let knock = HapticComposer.pattern(for: .knock)
        XCTAssertGreaterThan(alarm.totalIntensity, knock.totalIntensity)
    }

    func testCriticalEventsHaveLongerDuration() {
        let alarm = HapticComposer.pattern(for: .smokeAlarm)
        let knock = HapticComposer.pattern(for: .knock)
        XCTAssertGreaterThan(alarm.totalDuration, knock.totalDuration)
    }

    func testEveryEventHasAPattern() {
        for event in SoundEvent.allCases {
            XCTAssertFalse(HapticComposer.pattern(for: event).taps.isEmpty)
        }
    }
}

final class FeatureExtractorTests: XCTestCase {
    func testSilenceIsQuiet() {
        let f = FeatureExtractor.features(samples: [Float](repeating: 0, count: 4096))
        XCTAssertLessThan(f.loudnessDB, -80)
    }

    func testKnockProducesImpacts() {
        let f = FeatureExtractor.features(samples: SignalLibrary.pcm(event: .knock))
        XCTAssertGreaterThan(f.impacts, 0)
        XCTAssertGreaterThan(f.crestFactor, 2)
    }

    func testPeriodicAlarmIsDetected() {
        let f = FeatureExtractor.features(samples: SignalLibrary.pcm(event: .smokeAlarm))
        XCTAssertTrue(f.isPeriodic)
    }
}

@MainActor
final class SignalViewModelTests: XCTestCase {
    func testDemoRunRecordsDetections() {
        let vm = SignalViewModel()
        vm.runDemo()
        XCTAssertFalse(vm.detections.isEmpty)
        XCTAssertNotNil(vm.mostUrgent)
    }

    func testUnknownSoundIsNotRecorded() {
        let vm = SignalViewModel()
        _ = vm.ingest(samples: [Float](repeating: 0, count: 2048))
        XCTAssertTrue(vm.detections.isEmpty)
    }
}

final class AlertGateTests: XCTestCase {
    func testBalancedNeedsTwoConsecutiveHits() {
        var gate = AlertGate()
        let first = gate.admit(event: .knock, confidence: 0.8, interference: nil, severity: .low)
        let second = gate.admit(event: .knock, confidence: 0.8, interference: nil, severity: .low)
        XCTAssertFalse(first)
        XCTAssertTrue(second)
    }

    func testStreakResetsOnUnknown() {
        var gate = AlertGate()
        _ = gate.admit(event: .knock, confidence: 0.8, interference: nil, severity: .low)
        _ = gate.admit(event: .unknown, confidence: 0.9, interference: nil, severity: .low)
        let next = gate.admit(event: .knock, confidence: 0.8, interference: nil, severity: .low)
        XCTAssertFalse(next)
    }

    /// 危险事件只认一次，宁可信也不漏。
    func testCriticalBypassesDebounceAndInterference() {
        var gate = AlertGate()
        XCTAssertTrue(gate.admit(event: .smokeAlarm, confidence: 0.9,
                                interference: .appliance, severity: .critical))
    }

    func testLowConfidenceRejected() {
        var gate = AlertGate(sensitivity: .strict)
        for _ in 0..<5 {
            XCTAssertFalse(gate.admit(event: .knock, confidence: 0.5,
                                     interference: nil, severity: .low))
        }
    }

    func testInterferenceSuppressed() {
        var gate = AlertGate(sensitivity: .relaxed)
        XCTAssertFalse(gate.admit(event: .knock, confidence: 0.9,
                                  interference: .music, severity: .low))
    }
}

final class InterferenceDetectorTests: XCTestCase {
    func testSteadyHumIsAppliance() {
        let f = AudioFeatures(loudnessDB: -18, brightness: 0.2, zeroCrossingRate: 0.05,
                              crestFactor: 1.3, envelopeModulation: 1.02,
                              impacts: 0, isPeriodic: false)
        XCTAssertEqual(InterferenceDetector().classify(f), .appliance)
    }

    func testQuietRoomIsNotInterference() {
        XCTAssertNil(InterferenceDetector().classify(AudioFeatures.quiet()))
    }

    func testKnockIsNotClassifiedAsInterference() {
        let f = AudioFeatures(loudnessDB: -18, brightness: 0.2, zeroCrossingRate: 0.1,
                              crestFactor: 10, envelopeModulation: 3.2,
                              impacts: 3, isPeriodic: false)
        XCTAssertNil(InterferenceDetector().classify(f))
    }
}

final class SoundLocatorTests: XCTestCase {
    private let locator = SoundLocator()

    /// 单麦克风在物理上判不出方向——必须返回 nil 加说明，而不是编一个方位。
    func testSingleChannelRefusesToGuessBearing() {
        let result = locator.locate(level: nil, loudnessDB: -22, hasStereoInput: false)
        XCTAssertNil(result.bearing)
        XCTAssertEqual(result.bearingText, "方位未知")
        XCTAssertNotNil(result.caveat)
        XCTAssertLessThan(result.confidence, 0.3)
    }

    func testStereoLeftLouderMeansLeft() {
        let level = SoundLocator.ChannelLevel(left: -18, right: -28)
        XCTAssertEqual(locator.locate(level: level, loudnessDB: -18, hasStereoInput: true).bearing, .left)
    }

    func testStereoRightLouderMeansRight() {
        let level = SoundLocator.ChannelLevel(left: -30, right: -20)
        XCTAssertEqual(locator.locate(level: level, loudnessDB: -20, hasStereoInput: true).bearing, .right)
    }

    /// 差异太小就承认是「正前方」，而不是硬分左右。
    func testSmallDifferenceReadsAsFront() {
        let level = SoundLocator.ChannelLevel(left: -24, right: -25)
        XCTAssertEqual(locator.locate(level: level, loudnessDB: -24, hasStereoInput: true).bearing, .front)
    }

    func testBiggerDifferenceGivesHigherConfidence() {
        let small = SoundLocator.ChannelLevel(left: -22, right: -26)
        let big = SoundLocator.ChannelLevel(left: -10, right: -30)
        XCTAssertGreaterThan(locator.locate(level: big, loudnessDB: -20, hasStereoInput: true).confidence,
                             locator.locate(level: small, loudnessDB: -20, hasStereoInput: true).confidence)
    }

    func testDistanceBandsAreCoarse() {
        XCTAssertEqual(locator.distanceBand(forLoudness: -12), .veryNear)
        XCTAssertEqual(locator.distanceBand(forLoudness: -50), .far)
    }
}
