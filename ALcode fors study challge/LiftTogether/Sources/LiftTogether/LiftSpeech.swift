import Foundation

/// 朗读抽象：Playgrounds 与真机 AVSpeechSynthesizer 走同一接口。
protocol LiftSpeaking: AnyObject {
    func speak(_ text: String)
    func stop()
}

final class SpeechLiftSpeaker: LiftSpeaking {
    func speak(_ text: String) {
        #if canImport(AVFoundation)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.45        // 现场噪音大，宁可慢
        AVSpeechSynthesizer().speak(utterance)
        #endif
    }

    func stop() {
        #if canImport(AVFoundation)
        AVSpeechSynthesizer().stopSpeaking(at: .immediate)
        #endif
    }
}

final class SilentLiftSpeaker: LiftSpeaking {
    func speak(_ text: String) { _ = text }
    func stop() { }
}
