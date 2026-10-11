import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

@MainActor
final class SpeechCoach: NSObject, ObservableObject {
    enum State: Equatable { case idle, speaking }

    @Published private(set) var state: State = .idle

    #if canImport(AVFoundation)
    private let synthesizer = AVSpeechSynthesizer()
    #endif

    /// 读给谁听，是这个产品真正的分歧点：
    /// 老人耳背、医生在嘈杂诊室、子女远程 —— 所以**同一个卡片要能读给三方**。
    func speak(_ text: String, voiceIdentifier: String? = nil) {
        #if canImport(AVFoundation)
        guard !text.isEmpty else { return }
        state = .speaking
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier ?? "zh-CN")
            ?? AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.42        // 比默认慢一档，老人听得清
        utterance.postUtteranceDelay = 0.1
        synthesizer.speak(utterance)
        #else
        state = .idle
        #endif
    }

    func stop() {
        #if canImport(AVFoundation)
        synthesizer.stopSpeaking(at: .immediate)
        #endif
        state = .idle
    }

    /// 卡片的三种朗读稿
    enum Audience {
        case patient     // 老人自己听：慢、大白话
        case doctor      // 医生听：术语、正常语速
        case family      // 子女听：结论 + 要办的事
    }

    func script(for card: VisitCard, audience: Audience) -> String {
        switch audience {
        case .patient:
            return card.pathway.plainLanguage.joined(separator: "。") + "。医生建议去\(card.pathway.department)。"
        case .doctor:
            return "患者\(card.patient.age)岁，主诉\(card.headline)"
                + (card.onsets.isEmpty ? "" : "，病程\(card.onsets.joined(separator: "、"))")
                + "。\(card.pathway.departmentRationale)"
        case .family:
            return "本次就诊卡已生成：\(card.headline)，建议\(card.pathway.urgency.label)，去\(card.pathway.department)。请陪同前往并带上用药清单。"
        }
    }
}
