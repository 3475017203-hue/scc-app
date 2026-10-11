import Foundation
import SwiftUI

@MainActor
final class GuardViewModel: ObservableObject {
    @Published private(set) var verdict: FallVerdict?
    @Published private(set) var askedQuestions: [String] = []
    @Published private(set) var responses: [Bool] = []
    @Published private(set) var plan: EscalationPlan?

    let personName = "李伯"
    let location = "阳光小区 3 号楼 402"

    let detector = FallDetector()
    let planner = EscalationPlanner()
    let flow = VoiceCheckFlow(questions: VoicePrompt.questions)
    let contacts: [EmergencyContact] = [
        EmergencyContact(name: "老李", relation: "同住儿子", phone: "138****0001", tier: .neighbor),
        EmergencyContact(name: "小美", relation: "女儿", phone: "139****0002", tier: .family),
        EmergencyContact(name: "隔壁王阿姨", relation: "邻居", phone: "137****0003", tier: .neighbor, preAuthorized: false),
        EmergencyContact(name: "120", relation: "急救中心", phone: "120", tier: .emergency)
    ]

    private let voice: VoiceChecking

    init(voice: VoiceChecking = ScriptedVoiceCheck()) {
        self.voice = voice
    }

    func ingest(samples: [AccelSample]) {
        let v = detector.verdict(samples: samples)
        verdict = v
        plan = v.isFall ? planner.plan(contacts: contacts, verdict: v, personName: personName, location: location) : nil
    }

    func runVoiceCheck(responses scripted: [Bool]? = nil) {
        askedQuestions = []
        responses = []
        if let scripted { (voice as? ScriptedVoiceCheck)?.enqueue(scripted) }
        runNext()
    }

    private func runNext() {
        guard askedQuestions.count < flow.questions.count else { return }
        let question = flow.questions[askedQuestions.count]
        askedQuestions.append(question)
        voice.ask(question) { [weak self] responded in
            guard let self else { return }
            self.responses.append(responded)
            if responded {
                self.plan = nil   // 有人应了，静默升级到此为止
            } else {
                self.runNext()
            }
        }
    }

    var shouldEscalate: Bool {
        !responses.isEmpty && flow.needsEscalation(responses: responses)
    }
}
